`timescale 1ns/1ps
module fnt16_pipeline(input clk,input rst,input start,input inverse,input [223:0] din,output reg valid_out,output reg [223:0] dout);
    localparam integer Q=12289, ROOTW=4134, ROOTI=10984, NINV=11521;
    reg [13:0] s0[0:15],s1[0:15],s2[0:15],s3[0:15],s4[0:15];
    reg [223:0] calc_out; integer i,g,j,a,b,t,tw,expn,root;
    function integer bitrev4; input integer x; integer q; begin bitrev4=((x&1)<<3)|((x&2)<<1)|((x&4)>>1)|((x&8)>>3); end endfunction
    function integer mmul; input integer x,y; integer z; begin z=(x*y)%Q; if(z<0)z=z+Q; mmul=z; end endfunction
    function integer madd; input integer x,y; integer z; begin z=x+y; if(z>=Q)z=z-Q; madd=z; end endfunction
    function integer msub; input integer x,y; integer z; begin z=x-y; if(z<0)z=z+Q; msub=z; end endfunction
    function integer mpow; input integer x; input integer e; integer k,z,p; begin z=1;p=x;for(k=0;k<16;k=k+1)begin if((e>>k)&1)z=mmul(z,p);p=mmul(p,p);end mpow=z; end endfunction
    always @* begin
        root = inverse ? ROOTI : ROOTW;
        for(i=0;i<16;i=i+1) s0[i]=din[bitrev4(i)*14 +: 14];
        for(g=0;g<16;g=g+2) begin a=s0[g];b=s0[g+1];s1[g]=madd(a,b);s1[g+1]=msub(a,b);end
        for(g=0;g<16;g=g+4) for(j=0;j<2;j=j+1) begin a=s1[g+j];b=s1[g+j+2];tw=mpow(root,j*4);t=mmul(b,tw);s2[g+j]=madd(a,t);s2[g+j+2]=msub(a,t);end
        for(g=0;g<16;g=g+8) for(j=0;j<4;j=j+1) begin a=s2[g+j];b=s2[g+j+4];tw=mpow(root,j*2);t=mmul(b,tw);s3[g+j]=madd(a,t);s3[g+j+4]=msub(a,t);end
        for(g=0;g<16;g=g+16) for(j=0;j<8;j=j+1) begin a=s3[g+j];b=s3[g+j+8];tw=mpow(root,j);t=mmul(b,tw);s4[g+j]=madd(a,t);s4[g+j+8]=msub(a,t);end
        calc_out=0;
        for(i=0;i<16;i=i+1) calc_out[i*14 +: 14] = inverse ? mmul(s4[i],NINV) : s4[i];
    end
    always @(posedge clk) begin
        if(rst) begin valid_out<=0;dout<=0; end
        else begin valid_out<=start; if(start)dout<=calc_out; end
    end
endmodule
