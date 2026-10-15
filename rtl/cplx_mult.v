// Complex multiplier, Q15 fixed-point, combinational.
// (ar+j*ai)*(br+j*bi) => pr + j*pi
// Inputs are Q15 in [-1,1). Products are Q30, rounded to Q15 (half-up) and saturated.

module cplx_mult (
    input  wire signed [15:0] ar,
    input  wire signed [15:0] ai,
    input  wire signed [15:0] br,
    input  wire signed [15:0] bi,
    output wire signed [15:0] pr,
    output wire signed [15:0] pi
);

    reg [32:0] ac_re, ac_im;

    always @* begin
        ac_re = 33'sd0 + ($signed(ar) * $signed(br)) - ($signed(ai) * $signed(bi));
        ac_im = 33'sd0 + ($signed(ar) * $signed(bi)) + ($signed(ai) * $signed(br));
    end

    function automatic signed [15:0] qsat;
        input signed [32:0] v;
        reg signed [32:0] r;
        begin
            r = (v + 33'sd16384) >>> 15;
            if (r > 33'sd32767)       qsat = 16'sd32767;
            else if (r < -33'sd32768) qsat = -16'sd32768;
            else                      qsat = r[15:0];
        end
    endfunction

    assign pr = qsat(ac_re);
    assign pi = qsat(ac_im);

endmodule
