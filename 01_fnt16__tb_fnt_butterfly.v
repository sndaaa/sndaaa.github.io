`timescale 1ns/1ps
module tb_fnt_butterfly;
    reg [13:0] a,b,w; wire [13:0] y0,y1;
    fnt_butterfly dut(a,b,w,y0,y1);
    initial begin
        a=100;b=200;w=4134;#1;
        if(y0!=3537 || y1!=8952) begin $display("FAIL butterfly %0d %0d",y0,y1);$finish;end
        $display("PASS butterfly");$finish;
    end
endmodule
