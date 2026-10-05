`timescale 1ns/1ps
module tb_fnt_chain_bypass;
parameter B=16; reg clk=0,rst=1,start=0,bypass=1,cfg_we=0; reg [3:0] cfg_addr; reg [13:0] cfg_data; reg [223:0] din; reg [223:0] blocks[0:B-1]; integer i,j,errors; wire valid_out; wire [223:0] dout;
always #1 clk=~clk;
fnt_chain_top dut(clk,rst,start,bypass,cfg_we,cfg_addr,cfg_data,din,valid_out,dout);
initial begin errors=0; $readmemh("chain_vectors.mem",blocks); repeat(2) @(negedge clk); rst=0; for(i=0;i<B;i=i+1) begin din=blocks[i]; start=1; @(negedge clk); start=0; wait(valid_out==1'b1); #0.1; if(i==0)$display("DEBUG got=%0d exp=%0d",dout[13:0],blocks[i][13:0]); for(j=0;j<16;j=j+1) if(dout[j*14 +:14]!==blocks[i][j*14 +:14]) errors=errors+1; @(negedge clk); end if(errors==0)$display("PASS bypass blocks=%0d errors=0",B); else $display("FAIL bypass errors=%0d",errors); $finish; end
endmodule
