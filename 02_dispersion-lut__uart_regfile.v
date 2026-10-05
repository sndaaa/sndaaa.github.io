`timescale 1ns/1ps

// Byte-level packet parser. Packet format: A5, address_hi, address_lo,
// data_low, data_high. address_hi=0x00 writes all 256 LUT entries;
// address_hi=0xFF with address_lo=FE selects point size, FD controls bypass.
module uart_regfile(
    input clk,input rst,input byte_valid,input [7:0] byte_data,
    output reg cfg_we,output reg [7:0] cfg_addr,output reg [13:0] cfg_data,
    output reg [1:0] point_sel,output reg bypass
);
    reg [2:0] state; reg [7:0] addr,addr_hi,lo; localparam WAIT=0,ADDR_HI=1,ADDR_LO=2,LO=3,HI=4;
    always @(posedge clk) begin
        cfg_we<=0;
        if(rst)begin state<=WAIT;addr<=0;addr_hi<=0;lo<=0;cfg_addr<=0;cfg_data<=0;point_sel<=0;bypass<=0;end
        else if(byte_valid)begin
            case(state)
                WAIT:if(byte_data==8'hA5)state<=ADDR_HI;
                ADDR_HI:begin addr_hi<=byte_data;state<=ADDR_LO;end
                ADDR_LO:begin addr<=byte_data;state<=LO;end
                LO:begin lo<=byte_data;state<=HI;end
                HI:begin
                    cfg_addr<=addr;cfg_data<={byte_data,lo};
                    if(addr_hi==8'hFF && addr==8'hFE)point_sel<=lo[1:0];
                    else if(addr_hi==8'hFF && addr==8'hFD)bypass<=lo[0];
                    else cfg_we<=1;
                    state<=WAIT;
                end
                default:state<=WAIT;
            endcase
        end
    end
endmodule
