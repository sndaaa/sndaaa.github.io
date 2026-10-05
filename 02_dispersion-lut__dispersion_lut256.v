`timescale 1ns/1ps

module dispersion_lut256 #(parameter MAX_N=256)(
    input clk,input rst,input cfg_we,input [7:0] cfg_addr,input [13:0] cfg_data,input [1:0] point_sel,
    input [MAX_N*14-1:0] din,output reg [MAX_N*14-1:0] dout
);
    localparam integer Q=12289; reg [13:0] coeff[0:MAX_N-1]; integer i,n;
    function integer mmul; input integer a,b; integer t; begin t=(a*b)%Q;if(t<0)t=t+Q;mmul=t;end endfunction
    function integer n_for; input [1:0] s; begin case(s)2'd0:n_for=16;2'd1:n_for=64;default:n_for=256;endcase end endfunction
    always @(posedge clk) begin if(rst)for(i=0;i<MAX_N;i=i+1)coeff[i]<=1;else if(cfg_we)coeff[cfg_addr]<=cfg_data; end
    always @* begin n=n_for(point_sel);for(i=0;i<MAX_N;i=i+1)begin if(i<n)dout[i*14 +: 14]=mmul(din[i*14 +: 14],coeff[i]);else dout[i*14 +: 14]=0;end end
endmodule
