`timescale 1ns/1ps
module fnt_butterfly(input [13:0] a,input [13:0] b,input [13:0] w,output reg [13:0] y0,output reg [13:0] y1);
    localparam integer Q=12289; integer p,t0,t1;
    always @* begin
        p=(b*w)%Q; t0=a+p; if(t0>=Q)t0=t0-Q; t1=a-p; if(t1<0)t1=t1+Q; y0=t0; y1=t1;
    end
endmodule
