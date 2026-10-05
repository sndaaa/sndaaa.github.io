`timescale 1ns/1ps

// 16-point radix-2 DIT FNT/IFNT. Q=12289, N=16, primitive root=4134.
// The four butterfly stages are separated by registers. There are eight
// butterflies per stage (32 butterfly kernels total) and a block latency of
// four cycles after the input block is captured.
module fnt16_pipeline(
    input clk, input rst, input start, input inverse,
    input [223:0] din, output reg valid_out, output reg [223:0] dout
);
    localparam integer Q=12289, ROOT=4134, ROOT_INV=10984, N_INV=11521;
    reg [13:0] s0[0:15],s1[0:15],s2[0:15],s3[0:15],s4[0:15];
    reg inv_reg,v0,v1,v2,v3;
    reg [13:0] c1[0:15],c2[0:15],c3[0:15],c4[0:15];
    integer i,g,j,base;

    function integer madd; input integer a,b; integer t; begin t=a+b; if(t>=Q)t=t-Q; madd=t; end endfunction
    function integer msub; input integer a,b; integer t; begin t=a-b; if(t<0)t=t+Q; msub=t; end endfunction
    function integer mmul; input integer a,b; integer t; begin t=(a*b)%Q; if(t<0)t=t+Q; mmul=t; end endfunction
    function integer mpow; input integer a,e; integer k,t,x; begin x=a;t=1; for(k=0;k<16;k=k+1) begin if((e>>k)&1)t=mmul(t,x); x=mmul(x,x); end mpow=t; end endfunction
    function integer tw; input integer stage,idx,inv; integer e,rootv; begin e=idx << (3-stage); if(inv!=0)rootv=ROOT_INV;else rootv=ROOT; tw=mpow(rootv,e); end endfunction
    function integer bitrev4; input integer x; begin bitrev4=((x&1)<<3)|((x&2)<<1)|((x&4)>>1)|((x&8)>>3); end endfunction

    always @* begin
        for(i=0;i<16;i=i+1) begin c1[i]=0;c2[i]=0;c3[i]=0;c4[i]=0; end
        // stage 0, m=2
        for(g=0;g<8;g=g+1) begin base=2*g; c1[base]=madd(s0[base],mmul(s0[base+1],tw(0,0,inv_reg))); c1[base+1]=msub(s0[base],mmul(s0[base+1],tw(0,0,inv_reg))); end
        // stage 1, m=4
        for(g=0;g<4;g=g+1) begin base=4*g; for(j=0;j<2;j=j+1) begin c2[base+j]=madd(s1[base+j],mmul(s1[base+j+2],tw(1,j,inv_reg))); c2[base+j+2]=msub(s1[base+j],mmul(s1[base+j+2],tw(1,j,inv_reg))); end end
        // stage 2, m=8
        for(g=0;g<2;g=g+1) begin base=8*g; for(j=0;j<4;j=j+1) begin c3[base+j]=madd(s2[base+j],mmul(s2[base+j+4],tw(2,j,inv_reg))); c3[base+j+4]=msub(s2[base+j],mmul(s2[base+j+4],tw(2,j,inv_reg))); end end
        // stage 3, m=16
        base=0; for(j=0;j<8;j=j+1) begin c4[j]=madd(s3[j],mmul(s3[j+8],tw(3,j,inv_reg))); c4[j+8]=msub(s3[j],mmul(s3[j+8],tw(3,j,inv_reg))); end
    end

    always @(posedge clk) begin
        if(rst) begin
            v0<=0;v1<=0;v2<=0;v3<=0;valid_out<=0;inv_reg<=0;dout<=0;
            for(i=0;i<16;i=i+1) begin s0[i]<=0;s1[i]<=0;s2[i]<=0;s3[i]<=0;s4[i]<=0; end
        end else begin
            v0<=start;v1<=v0;v2<=v1;v3<=v2;valid_out<=v3;
            if(start) begin inv_reg<=inverse; for(i=0;i<16;i=i+1) s0[i]<=din[bitrev4(i)*14 +: 14]; end
            if(v0) for(i=0;i<16;i=i+1) s1[i]<=c1[i];
            if(v1) for(i=0;i<16;i=i+1) s2[i]<=c2[i];
            if(v2) for(i=0;i<16;i=i+1) s3[i]<=c3[i];
            if(v3) begin
                for(i=0;i<16;i=i+1) begin
                    if(inv_reg) begin s4[i]<=mmul(c4[i],N_INV); dout[i*14 +: 14]<=mmul(c4[i],N_INV); end
                    else begin s4[i]<=c4[i]; dout[i*14 +: 14]<=c4[i]; end
                end
            end
        end
    end
endmodule
