`timescale 1ns/1ps

// Full serial-stream configurable accelerator. A byte-level config injection
// port is provided for simulation; uart_rx_8n1 can be connected on hardware.
module fnt_configurable_top #(parameter MAX_N=256)(
    input clk,input rst,
    input uart_rx,input cfg_byte_valid,input [7:0] cfg_byte,
    input in_valid,input in_sof,input [13:0] in_symbol,
    output out_valid,output out_sof,output out_last,output [13:0] out_symbol,
    output [1:0] point_sel_out,output bypass_out
);
    wire uart_valid;wire [7:0] uart_byte;wire byte_valid=uart_valid|cfg_byte_valid;wire [7:0] byte_data=cfg_byte_valid?cfg_byte:uart_byte;
    wire cfg_we;wire [7:0] cfg_addr;wire [13:0] cfg_data;wire [1:0] point_sel;wire bypass;
    wire block_start;wire [MAX_N*14-1:0] block_data;reg [MAX_N*14-1:0] bypass_hold;
    wire fwd_done,inv_done;wire fwd_busy,inv_busy;wire [MAX_N*14-1:0] fwd_data,comp_data,inv_data,selected_data;
    // uart_regfile only asserts cfg_we for LUT writes; FF/FE and FF/FD are control packets.
    wire lut_we=cfg_we;
    uart_rx_8n1 #(.CLKS_PER_BIT(4)) u_rx(clk,rst,uart_rx,uart_valid,uart_byte);
    uart_regfile u_reg(clk,rst,byte_valid,byte_data,cfg_we,cfg_addr,cfg_data,point_sel,bypass);
    stream_to_block_cfg #(.MAX_N(MAX_N)) u_in(clk,rst,in_valid,in_sof,in_symbol,point_sel,block_start,block_data);
    fnt_seq_core #(.MAX_N(MAX_N)) u_fwd(clk,rst,block_start,1'b0,point_sel,block_data,fwd_done,fwd_busy,fwd_data);
    dispersion_lut256 #(.MAX_N(MAX_N)) u_lut(clk,rst,lut_we,cfg_addr,cfg_data,point_sel,fwd_data,comp_data);
    fnt_seq_core #(.MAX_N(MAX_N)) u_inv(clk,rst,fwd_done,1'b1,point_sel,comp_data,inv_done,inv_busy,inv_data);
    assign selected_data=bypass?bypass_hold:inv_data;
    block_to_stream_cfg #(.MAX_N(MAX_N)) u_out(clk,rst,inv_done,point_sel,selected_data,out_valid,out_sof,out_last,out_symbol);
    assign point_sel_out=point_sel;assign bypass_out=bypass;
    always @(posedge clk)begin if(rst)bypass_hold<=0;else if(block_start)bypass_hold<=block_data;end
endmodule
