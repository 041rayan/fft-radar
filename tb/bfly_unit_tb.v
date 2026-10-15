`timescale 1ns/1ps
// Butterfly unit self-check. Expected values were precomputed by the Python
// fixed-point model (same rounding rules); any mismatch = FAIL.

module bfly_unit_tb;
    reg signed [15:0] ar, ai, br, bi, wr, wi;
    wire signed [15:0] sr, si, dr, di;

    cplx_butterfly ubf (.ar(ar),.ai(ai),.br(br),.bi(bi),
                        .wr(wr),.wi(wi),.sr(sr),.si(si),.dr(dr),.di(di));

    integer k, fails;
    reg signed [15:0] e_sr, e_si, e_dr, e_di;

    // (ar,ai,br,bi,wr,wi, e_sr,e_si,e_dr,e_di)
    integer tv [0:69];
    initial begin
        tv[0] =  32767; tv[1] =      0; tv[2] =   1000; tv[3] =    500;
        tv[4] =  32767; tv[5] =      0; tv[6] =  16883; tv[7] =    250;
        tv[8] =  15883; tv[9] =   -250;
        tv[10]=  10000; tv[11]=   2000; tv[12]=   3000; tv[13]=   4000;
        tv[14]=      0; tv[15]= -32768; tv[16]=   6500; tv[17]=   3000;
        tv[18]=  -1000; tv[19]=  -3500;
        tv[20]= -24645; tv[21]=  16437; tv[22]=   9274; tv[23]=  -3668;
        tv[24]=  -4020; tv[25]=  21515; tv[26]=  -7686; tv[27]=   6384;
        tv[28]=  -4519; tv[29]= -12369;
        tv[30]= -24844; tv[31]=  11842; tv[32]= -17912; tv[33]= -24350;
        tv[34]=   1588; tv[35]=  28537; tv[36]= -21378; tv[37]=  -6254;
        tv[38]= -15927; tv[39]=  -2142;
        tv[40]=  14145; tv[41]=  15668; tv[42]=  13048; tv[43]=  17163;
        tv[44]=    793; tv[45]= -22314; tv[46]=  13596; tv[47]=  16415;
        tv[48]=   -496; tv[49]=   -391;
        tv[50]=  20384; tv[51]=  -2977; tv[52]=     21; tv[53]=  -7753;
        tv[54]= -19048; tv[55]=  25605; tv[56]=  10202; tv[57]=  -5365;
        tv[58]=  -7784; tv[59]=   6567;
        tv[60]=  16894; tv[61]=   8631; tv[62]=  -5856; tv[63]=  19365;
        tv[64]=   2725; tv[65]=  -3396; tv[66]=   5519; tv[67]=  13998;
        tv[68]=    390; tv[69]=  -1625;

        fails = 0;
        for (k = 0; k < 7; k = k + 1) begin
            ar = tv[10*k+0]; ai = tv[10*k+1]; br = tv[10*k+2]; bi = tv[10*k+3];
            wr = tv[10*k+4]; wi = tv[10*k+5];
            e_sr = tv[10*k+6]; e_si = tv[10*k+7];
            e_dr = tv[10*k+8]; e_di = tv[10*k+9];
            #1;
            if (sr !== e_sr || si !== e_si || dr !== e_dr || di !== e_di) begin
                $display("MISMATCH k=%0d got s=(%0d,%0d) d=(%0d,%0d) exp s=(%0d,%0d) d=(%0d,%0d)",
                         k, $signed(sr),$signed(si),$signed(dr),$signed(di),
                         e_sr,e_si,e_dr,e_di);
                fails = fails + 1;
            end
        end
        if (fails == 0)
            $display("UNIT OK: butterfly matches reference for all %0d vectors", 7);
        else
            $display("UNIT FAIL: %0d mismatches", fails);
        $finish;
    end
endmodule