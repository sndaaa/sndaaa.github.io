`timescale 1ns/1ps
module stream_to_block16(input clk,input rst,input in_valid,input in_sof,input [13:0] din,output reg block_start,output reg [223:0] block_data);
    reg [3:0] count;
    always @(posedge clk) begin
        block_start<=0;
        if(rst) begin count<=0; block_data<=0; end
        else if(in_valid) begin
            if(in_sof) count<=0;
            block_data[count*14 +: 14]<=din;
            if(count==15) begin block_start<=1; count<=0; end else count<=count+1'b1;
        end
    end
endmodule
module block_to_stream16(input clk,input rst,input start,input [223:0] block_data,output reg out_valid,output reg [3:0] index,output reg [13:0] dout);
    reg [223:0] hold; reg busy;
    always @(posedge clk) begin
        if(rst) begin hold<=0;busy<=0;index<=0;out_valid<=0;dout<=0; end
        else begin out_valid<=0; if(start) begin hold<=block_data;busy<=1;index<=0; end else if(busy) begin dout<=hold[index*14 +: 14];out_valid<=1; if(index==15) busy<=0; else index<=index+1'b1; end end
    end
endmodule
