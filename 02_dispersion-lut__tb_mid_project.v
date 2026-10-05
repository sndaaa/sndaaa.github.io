`timescale 1ns/1ps
module tb_mid_project;
    localparam MAX_N=256; localparam TOTAL=352;
    reg clk=0,rst=1,uart_rx=1,cfg_byte_valid=0;reg [7:0] cfg_byte;reg in_valid=0,in_sof=0;reg [13:0] in_symbol;
    reg [13:0] input_mem[0:TOTAL-1];reg [13:0] expected_mem[0:TOTAL-1];reg [13:0] coeff_mem[0:335];wire out_valid,out_sof,out_last;wire [13:0] out_symbol;wire [1:0] point_sel;wire bypass;
    integer fd,mode,j,ptr,optr,n,cptr;reg [13:0] got;
    always #1 clk=~clk;
    fnt_configurable_top #(.MAX_N(MAX_N)) dut(clk,rst,uart_rx,cfg_byte_valid,cfg_byte,in_valid,in_sof,in_symbol,out_valid,out_sof,out_last,out_symbol,point_sel,bypass);
    task send_byte;input [7:0] x;begin cfg_byte=x;cfg_byte_valid=1;@(negedge clk);cfg_byte_valid=0;@(negedge clk);end endtask
    task send_point;input [1:0] s;begin send_byte(8'hA5);send_byte(8'hFF);send_byte(8'hFE);send_byte({6'd0,s});send_byte(8'h00);end endtask
    task send_bypass;input bit x;begin send_byte(8'hA5);send_byte(8'hFF);send_byte(8'hFD);send_byte({7'd0,x});send_byte(8'h00);end endtask
    task send_coeff;input [7:0] a;input [13:0] v;begin send_byte(8'hA5);send_byte(8'h00);send_byte(a);send_byte(v[7:0]);send_byte({2'd0,v[13:8]});end endtask
    task send_symbols;input integer count;begin for(j=0;j<count;j=j+1)begin in_symbol=input_mem[ptr];in_sof=(j==0);in_valid=1;@(negedge clk);in_valid=0;in_sof=0;ptr=ptr+1;end end endtask
    initial begin
        $readmemh("mid_input.mem",input_mem);$readmemh("mid_expected.mem",expected_mem);$readmemh("mid_coeff.mem",coeff_mem);fd=$fopen("mid_results.csv","w");$fwrite(fd,"mode,idx,got,expected,bypass\n");
        repeat(2)@(negedge clk);rst=0;ptr=0;optr=0;cptr=0;
        for(mode=0;mode<3;mode=mode+1)begin
            if(mode==0)n=16;else if(mode==1)n=64;else n=256;send_point(mode[1:0]);send_bypass(0);
            // LUT coefficients are delivered through the same packet interface in the Python-generated order.
            for(j=0;j<n;j=j+1)begin send_coeff(j[7:0],coeff_mem[cptr]);cptr=cptr+1;end
            send_symbols(n);j=0;while(j<n)begin @(negedge clk);if(out_valid)begin got=out_symbol;$fwrite(fd,"%0d,%0d,%0d,%0d,%0d\n",mode,j,got,expected_mem[optr],bypass);j=j+1;optr=optr+1;end end
        end
        send_point(0);send_bypass(1);ptr=0;send_symbols(16);j=0;while(j<16)begin @(negedge clk);if(out_valid)begin got=out_symbol;$fwrite(fd,"3,%0d,%0d,%0d,%0d\n",j,got,input_mem[j],bypass);j=j+1;end end
        $fclose(fd);$finish;
    end
endmodule
