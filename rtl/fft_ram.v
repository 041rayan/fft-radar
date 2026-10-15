// Dual-port RAM, N x {re,im}, each part W-bit.
// Asynchronous (combinational) read allows a clean single-cycle in-place
// butterfly: read A/B combinationally, write A/B on the clock edge.

module fft_ram #(
    parameter N  = 256,
    parameter W  = 16,
    parameter AW = 8
) (
    input  wire               clk,
    input  wire [AW-1:0]      raddr_a, raddr_b,
    output wire signed [W-1:0] ram_re_a, ram_im_a,
    output wire signed [W-1:0] ram_re_b, ram_im_b,
    input  wire               wea,
    input  wire [AW-1:0]      waddr_a,
    input  wire signed [W-1:0] wd_re_a, wd_im_a,
    input  wire               web,
    input  wire [AW-1:0]      waddr_b,
    input  wire signed [W-1:0] wd_re_b, wd_im_b
);

    reg [W-1:0] mem_re [0:N-1];
    reg [W-1:0] mem_im [0:N-1];

    assign ram_re_a = $signed(mem_re[raddr_a]);
    assign ram_im_a = $signed(mem_im[raddr_a]);
    assign ram_re_b = $signed(mem_re[raddr_b]);
    assign ram_im_b = $signed(mem_im[raddr_b]);

    always @(posedge clk) begin
        if (wea) begin
            mem_re[waddr_a] <= wd_re_a;
            mem_im[waddr_a] <= wd_im_a;
        end
        if (web) begin
            mem_re[waddr_b] <= wd_re_b;
            mem_im[waddr_b] <= wd_im_b;
        end
    end

endmodule
