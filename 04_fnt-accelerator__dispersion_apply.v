`timescale 1ns/1ps
module dispersion_apply(input clk,input rst,input cfg_we,input [3:0] cfg_addr,input [13:0] cfg_data,input [223:0] din,output reg [223:0] dout);
    localparam integer Q=12289; reg [13:0] coeff[0:15]; integer i,t;
    always @(posedge clk) begin if(rst) for(i=0;i<16;i=i+1) coeff[i]<=14'd1; else if(cfg_we) coeff[cfg_addr]<=cfg_data; end
    always @* begin for(i=0;i<16;i=i+1) begin t=(din[i*14 +: 14]*coeff[i])%Q; if(t<0)t=t+Q; dout[i*14 +: 14]=t; end end
endmodule
