// Radix-2 DIF butterfly, combinational, Q15 fixed-point.
//
//   s = (a + b) >> 1          (arithmetic, keeps result in [-1,1))
//   d = ((a - b) >> 1) * w    (twiddle multiply via cplx_mult)
//
// The unconditional >>1 per stage yields a total scale of 1/2^log2(N) (1/256
// for N=256), matching the golden reference in py/golden/fft_ref.py.

module cplx_butterfly (
    input  wire signed [15:0] ar, ai,
    input  wire signed [15:0] br, bi,
    input  wire signed [15:0] wr, wi,
    output wire signed [15:0] sr, si,
    output wire signed [15:0] dr, di
);

    reg signed [16:0] sum_re, sum_im, diff_re, diff_im;
    wire signed [15:0] din_re, din_im;

    /* verilator lint_off UNUSEDSIGNAL */
    function automatic signed [15:0] half16;
        input signed [16:0] v;         // v[0] is intentionally discarded by the >>1
        begin
            half16 = v[16:1];          // >>1 (arithmetic)
        end
    endfunction
    /* verilator lint_on UNUSEDSIGNAL */

    always @* begin
        sum_re  = $signed({ar[15], ar}) + $signed({br[15], br});
        sum_im  = $signed({ai[15], ai}) + $signed({bi[15], bi});
        diff_re = $signed({ar[15], ar}) - $signed({br[15], br});
        diff_im = $signed({ai[15], ai}) - $signed({bi[15], bi});
    end

    assign sr = half16(sum_re);
    assign si = half16(sum_im);

    assign din_re = half16(diff_re);
    assign din_im = half16(diff_im);

    cplx_mult umult (
        .ar(din_re), .ai(din_im),
        .br(wr),     .bi(wi),
        .pr(dr),     .pi(di)
    );

endmodule
