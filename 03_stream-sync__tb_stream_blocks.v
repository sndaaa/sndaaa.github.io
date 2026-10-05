`timescale 1ns/1ps
module tb_stream_blocks;
    reg clk=0,rst=1,in_valid=0,in_sof=0; reg [13:0] din; wire block_start; wire [223:0] block_data; integer i;
    always #1 clk=~clk;
    stream_to_block16 u(clk,rst,in_valid,in_sof,din,block_start,block_data);
    initial begin
        repeat(2) @(negedge clk); rst=0;
        for(i=0;i<16;i=i+1) begin din=i;in_sof=(i==0);in_valid=1;@(negedge clk); end
        in_valid=0;in_sof=0;
        if(!block_start || block_data[0 +: 14]!==0 || block_data[210 +: 14]!==15) begin $display("FAIL stream");$finish;end
        $display("PASS stream");$finish;
    end
endmodule
