`timescale 1ns/1ps

`ifndef CURRENT_CASE
`define CURRENT_CASE "tone"
`endif

module fft_tb;

    localparam N = 256;

    reg clk, rst_n;
    reg load_en, fft_start;
    reg signed [15:0] din_re, din_im;
    wire busy, fft_done, out_valid;
    wire [7:0] out_idx;
    wire signed [15:0] dout_re, dout_im;

    fft_core #(.N(N), .W(16), .LOG2N(8), .AW(8)) dut (
        .clk(clk), .rst_n(rst_n),
        .load_en(load_en),
        .din_re(din_re), .din_im(din_im),
        .fft_start(fft_start),
        .busy(busy), .fft_done(fft_done),
        .out_valid(out_valid), .out_idx(out_idx),
        .dout_re(dout_re), .dout_im(dout_im)
    );

    reg [15:0] data [0:511];
    reg signed [15:0] mem_re [0:N-1];
    reg signed [15:0] mem_im [0:N-1];
    reg [15:0] out_re [0:N-1];
    reg [15:0] out_im [0:N-1];

    integer i, fh;

    always #5 clk = ~clk;

    initial begin
        $dumpfile({"sim/", `CURRENT_CASE, "_wave.vcd"});
        $dumpvars(0, fft_tb);

        clk      = 0;
        rst_n    = 0;
        load_en  = 0;
        fft_start = 0;
        din_re   = 0;
        din_im   = 0;

        // load stimulus from hex files
        $readmemh({"stim/", `CURRENT_CASE, "_in.hex"}, data);
        for (i = 0; i < N; i = i + 1) begin
            mem_re[i] = data[2*i];
            mem_im[i] = data[2*i + 1];
        end

        #30 rst_n = 1;
        #10;

        // Load phase: one sample per cycle
        for (i = 0; i < N; i = i + 1) begin
            @(posedge clk);
            din_re   = mem_re[i];
            din_im   = mem_im[i];
            load_en  = 1;
            @(posedge clk);
            load_en  = 0;
            din_re   = 0;
            din_im   = 0;
        end

        // Start the FFT
        @(posedge clk);
        fft_start = 1;
        @(posedge clk);
        fft_start = 0;

        // Wait for completion
        wait (fft_done == 1);

        // Collect streaming output (async dout, registered out_valid/out_idx)
        i = 0;
        while (i < N) begin
            @(posedge clk);
            if (out_valid) begin
                out_re[out_idx] = dout_re;
                out_im[out_idx] = dout_im;
                i = i + 1;
            end
        end

        fh = $fopen({"sim/", `CURRENT_CASE, "_out.txt"}, "w");
        for (i = 0; i < N; i = i + 1)
            $fwrite(fh, "%d %d\n", $signed(out_re[i]), $signed(out_im[i]));
        $fclose(fh);

        $display("SIM DONE: %s", `CURRENT_CASE);
        $finish;
    end

    // Watchdog: a healthy run takes ~1800 cycles; anything past 1 ms is a hang.
    initial begin
        #1_000_000;
        $display("TIMEOUT: %s did not finish", `CURRENT_CASE);
        $finish;
    end

endmodule