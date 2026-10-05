`timescale 1ns/1ps

module stream_to_block_cfg #(parameter MAX_N=256)(
    input clk,input rst,input in_valid,input in_sof,input [13:0] din,input [1:0] point_sel,
    output reg block_start,output reg [MAX_N*14-1:0] block_data
);
    reg [8:0] count; integer i,n;
    function integer n_for; input [1:0] s; begin case(s)2'd0:n_for=16;2'd1:n_for=64;default:n_for=256;endcase end endfunction
    always @(posedge clk)begin
        block_start<=0;n=n_for(point_sel);
        if(rst)begin count<=0;block_data<=0;end
        else if(in_valid)begin
            if(in_sof)count<=0;
            block_data[count*14 +: 14]<=din;
            if(count==n-1)begin block_start<=1;count<=0;end else count<=count+1'b1;
        end
    end
endmodule

module block_to_stream_cfg #(parameter MAX_N=256)(
    input clk,input rst,input start,input [1:0] point_sel,input [MAX_N*14-1:0] block_data,
    output reg out_valid,output reg out_sof,output reg out_last,output reg [13:0] dout
);
    reg [8:0] count; reg busy; reg [MAX_N*14-1:0] hold; integer n;
    function integer n_for; input [1:0] s; begin case(s)2'd0:n_for=16;2'd1:n_for=64;default:n_for=256;endcase end endfunction
    always @(posedge clk)begin
        out_valid<=0;out_sof<=0;out_last<=0;n=n_for(point_sel);
        if(rst)begin count<=0;busy<=0;hold<=0;dout<=0;end
        else if(start)begin hold<=block_data;count<=0;busy<=1;end
        else if(busy)begin dout<=hold[count*14 +: 14];out_valid<=1;out_sof<=(count==0);out_last<=(count==n-1);if(count==n-1)busy<=0;else count<=count+1'b1;end
    end
endmodule
