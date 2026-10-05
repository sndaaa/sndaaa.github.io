`timescale 1ns/1ps
module fnt_butterfly(input clk,input rst,input valid_in,input [13:0] a,input [13:0] b,input [13:0] w,output reg valid_out,output reg [13:0] y0,output reg [13:0] y1);
    localparam integer Q=12289; integer t,sa,sb;
    always @(posedge clk) begin
        valid_out<=valid_in;
        if(rst) begin y0<=0; y1<=0; end
        else begin t=(b*w)%Q; sa=a+t; if(sa>=Q)sa=sa-Q; sb=a-t; if(sb<0)sb=sb+Q; y0<=sa; y1<=sb; end
    end
endmodule

