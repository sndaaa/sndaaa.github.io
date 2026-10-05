`timescale 1ns/1ps
module tb_fnt_butterfly;
reg clk=0,rst=1,valid_in=0; reg [13:0] a,b,w; wire valid_out; wire [13:0] y0,y1; integer t0,t1;
always #1 clk=~clk;
fnt_butterfly u(clk,rst,valid_in,a,b,w,valid_out,y0,y1);
initial begin repeat(2) @(negedge clk); rst=0; a=14'd100;b=14'd200;w=14'd3;valid_in=1;@(negedge clk); t0=(100+200*3)%12289;t1=((100-200*3)%12289+12289)%12289; if(valid_out!==1'b1 || y0!==t0 || y1!==t1) $fatal(1,"FAIL butterfly"); else $display("PASS butterfly"); valid_in=0; $finish; end
endmodule
