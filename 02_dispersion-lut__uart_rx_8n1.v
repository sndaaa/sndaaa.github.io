`timescale 1ns/1ps

// Small 8N1 UART receiver. CLKS_PER_BIT is set from the board clock/baud rate.
module uart_rx_8n1 #(parameter CLKS_PER_BIT=4)(input clk,input rst,input rx,output reg byte_valid,output reg [7:0] byte_data);
    reg [2:0] state; reg [15:0] count; reg [2:0] bit_idx; reg [7:0] shift; localparam IDLE=0,START=1,DATA=2,STOP=3;
    always @(posedge clk) begin
        byte_valid<=0;
        if(rst)begin state<=IDLE;count<=0;bit_idx<=0;shift<=0;byte_data<=0;end
        else case(state)
            IDLE:if(!rx)begin count<=0;state<=START;end
            START:if(count==(CLKS_PER_BIT/2)-1)begin count<=0;if(!rx)begin bit_idx<=0;state<=DATA;end else state<=IDLE;end else count<=count+1'b1;
            DATA:if(count==CLKS_PER_BIT-1)begin count<=0;shift[bit_idx]<=rx;if(bit_idx==7)state<=STOP;else bit_idx<=bit_idx+1'b1;end else count<=count+1'b1;
            STOP:if(count==CLKS_PER_BIT-1)begin count<=0;byte_data<=shift;byte_valid<=1;state<=IDLE;end else count<=count+1'b1;
            default:state<=IDLE;
        endcase
    end
endmodule
