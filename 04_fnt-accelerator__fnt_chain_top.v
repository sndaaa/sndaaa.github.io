`timescale 1ns/1ps

// Complete block accelerator: FNT -> configurable dispersion compensation -> IFNT.
module fnt_chain_top(
    input clk, input rst, input start, input bypass,
    input cfg_we, input [3:0] cfg_addr, input [13:0] cfg_data,
    input [223:0] din, output reg valid_out, output reg [223:0] dout
);
    wire fwd_valid,inv_valid; wire [223:0] fwd_data,comp_data,inv_data;
    fnt16_pipeline u_fwd(clk,rst,start,1'b0,din,fwd_valid,fwd_data);
    dispersion_apply u_comp(clk,rst,cfg_we,cfg_addr,cfg_data,fwd_data,comp_data);
    fnt16_pipeline u_inv(clk,rst,fwd_valid,1'b1,comp_data,inv_valid,inv_data);
    reg [223:0] bypass_hold;
    always @(posedge clk) begin
        if(rst) begin valid_out<=0;dout<=0;bypass_hold<=0; end
        else begin
            if(start) bypass_hold<=din;
            valid_out<=inv_valid;
            if(inv_valid) begin if(bypass)dout<=bypass_hold;else dout<=inv_data; end
        end
    end
endmodule
