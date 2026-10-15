// Top-level 256-point (generic N) radix-2, decimation-in-frequency (DIF)
// fixed-point FFT core.
//
// Folding design: a single shared butterfly datapath processes all
// N/2 * log2(N) butterflies under an FSM. Async-read dual-port RAM allows a
// one-cycle in-place butterfly with no read-modify-write hazard.
//
// Load  : N complex samples via din_re/din_im, one per load_en edge, stored
//         in NATURAL order.
// Start : assert fft_start after N loads.
// Stream: while out_valid, one output per cycle in NATURAL bin order; internal
//         write-back is bit-reversed (DIF), so each bin k reads mem[bitrev(k)].
// The butterfly does s=(a+b)>>1, d=((a-b)>>1)*W each stage => total scale 1/N.

module fft_core #(
    parameter N      = 256,
    parameter W      = 16,
    parameter LOG2N  = 8,
    parameter AW     = 8
) (
    input  wire               clk,
    input  wire               rst_n,

    input  wire               load_en,
    input  wire signed [W-1:0] din_re,
    input  wire signed [W-1:0] din_im,

    input  wire               fft_start,
    output wire               busy,
    output wire               fft_done,
    output wire               out_valid,
    output wire [AW-1:0]      out_idx,
    output wire signed [W-1:0] dout_re,
    output wire signed [W-1:0] dout_im
);

    localparam [1:0] S_IDLE   = 2'd0,
                     S_PROC   = 2'd1,
                     S_DONE   = 2'd2,
                     S_STREAM = 2'd3;

    reg  [1:0]      state;
    reg  [AW-1:0]   load_cnt;
    reg  [LOG2N-1:0] stage_reg;
    reg  [AW-1:0]   bcnt_reg;
    reg  [AW-1:0]   out_idx_reg;

    // ------------------------------------------------------------------ //
    // Combinational butterfly addressing (DIF, decreasing span)
    //   span   = N / 2^(stage+1)
    //   A = g*2*span + j,  B = A + span,  tw = j << stage
    // ------------------------------------------------------------------ //
    wire [AW-1:0] span  = 1 << (LOG2N - 1 - stage_reg);
    wire [AW-1:0] jw    = bcnt_reg & (span - 1);                // within-span
    wire [AW-1:0] gw    = bcnt_reg >> (LOG2N - 1 - stage_reg);  // group index
    wire [AW-1:0] base  = (gw * span) << 1;                    // g*2*span
    wire [AW-1:0] p_addr_a = base | jw;
    wire [AW-1:0] p_addr_b = p_addr_a + span;
    wire [AW-1:0] tw_addr  = jw << stage_reg;

    // Bit-reversed load address
    function [AW-1:0] bitrev;
        input [AW-1:0] x;
        integer k;
        begin
            bitrev = {AW{1'b0}};
            for (k = 0; k < LOG2N; k = k + 1)
                bitrev = {bitrev[AW-2:0], x[k]};
        end
    endfunction

    // ------------------------------------------------------------------ //
    // Datapath
    // ------------------------------------------------------------------ //
    wire signed [W-1:0] tw_re, tw_im;
    twiddle_rom #(.N(N), .W(W), .AW(AW)) urom (
        .addr(tw_addr),
        .wr(tw_re),
        .wi(tw_im)
    );

    wire [AW-1:0] ram_a_addr = (state == S_PROC) ? p_addr_a :
                               (state == S_STREAM) ? bitrev(out_idx_reg) :
                                                    load_cnt;
    wire [AW-1:0] ram_b_addr = p_addr_b;

    wire signed [W-1:0] ram_re_a, ram_im_a, ram_re_b, ram_im_b;
    wire wea = (state == S_PROC) ? 1'b1 : (state == S_IDLE) ? load_en : 1'b0;
    wire web = (state == S_PROC);
    wire [AW-1:0] waddr_a = (state == S_PROC) ? p_addr_a : load_cnt;
    wire [AW-1:0] waddr_b = p_addr_b;
    wire signed [W-1:0] wd_re_a, wd_im_a, wd_re_b, wd_im_b;

    wire signed [W-1:0] s_re, s_im, d_re, d_im;
    cplx_butterfly ubf (
        .ar(ram_re_a), .ai(ram_im_a),
        .br(ram_re_b), .bi(ram_im_b),
        .wr(tw_re), .wi(tw_im),
        .sr(s_re), .si(s_im), .dr(d_re), .di(d_im)
    );

    assign wd_re_a = (state == S_PROC) ? s_re : din_re;
    assign wd_im_a = (state == S_PROC) ? s_im : din_im;
    assign wd_re_b = d_re;
    assign wd_im_b = d_im;

    fft_ram #(.N(N), .W(W), .AW(AW)) uram (
        .clk(clk),
        .raddr_a(ram_a_addr),  .raddr_b(ram_b_addr),
        .ram_re_a(ram_re_a),   .ram_im_a(ram_im_a),
        .ram_re_b(ram_re_b),   .ram_im_b(ram_im_b),
        .wea(wea), .waddr_a(waddr_a), .wd_re_a(wd_re_a), .wd_im_a(wd_im_a),
        .web(web), .waddr_b(waddr_b), .wd_re_b(wd_re_b), .wd_im_b(wd_im_b)
    );

    // ------------------------------------------------------------------ //
    // Outputs (combinational)
    // ------------------------------------------------------------------ //
    assign busy      = (state != S_IDLE);
    assign fft_done  = (state == S_DONE);
    assign out_valid = (state == S_STREAM);
    assign out_idx   = out_idx_reg;
    assign dout_re   = (state == S_STREAM) ? ram_re_a : {W{1'b0}};
    assign dout_im   = (state == S_STREAM) ? ram_im_a : {W{1'b0}};

    // ------------------------------------------------------------------ //
    // FSM
    // ------------------------------------------------------------------ //
    // Wrap points, sized to the counters they are compared against.
    localparam [AW-1:0] LAST_BCNT = AW'(N / 2 - 1);
    localparam [AW-1:0] LAST_OUT  = AW'(N - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            load_cnt     <= {AW{1'b0}};
            stage_reg    <= {LOG2N{1'b0}};
            bcnt_reg     <= {AW{1'b0}};
            out_idx_reg  <= {AW{1'b0}};
        end
        else case (state)
            S_IDLE: begin
                if (load_en)
                    load_cnt <= load_cnt + 1;
                else if (fft_start) begin
                    state     <= S_PROC;
                    stage_reg <= {LOG2N{1'b0}};
                    bcnt_reg  <= {AW{1'b0}};
                    load_cnt  <= {AW{1'b0}};
                end
            end

            S_PROC: begin
                if (bcnt_reg == LAST_BCNT) begin
                    if (stage_reg == LOG2N - 1) begin
                        state <= S_DONE;
                    end else begin
                        stage_reg <= stage_reg + 1;
                        bcnt_reg  <= {AW{1'b0}};
                    end
                end else begin
                    bcnt_reg <= bcnt_reg + 1;
                end
            end

            S_DONE: begin
                out_idx_reg <= {AW{1'b0}};
                state       <= S_STREAM;
            end

            S_STREAM: begin
                if (out_idx_reg == LAST_OUT) begin
                    out_idx_reg <= {AW{1'b0}};
                    state       <= S_IDLE;
                end else begin
                    out_idx_reg <= out_idx_reg + 1;
                end
            end

            default: state <= S_IDLE;
        endcase
    end

endmodule
