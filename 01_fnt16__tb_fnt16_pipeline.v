`timescale 1ns/1ps
module tb_fnt16_pipeline;
    reg clk=0,rst=1,start=0,inverse=0; reg [223:0] din; reg [13:0] input_mem[0:15];
    wire valid_out; wire [223:0] dout; integer i,fd;
    always #1 clk=~clk;
    fnt16_pipeline dut(clk,rst,start,inverse,din,valid_out,dout);
    initial begin
        $readmemh("small1_input.mem",input_mem); din=0;
        for(i=0;i<16;i=i+1) din[i*14 +: 14]=input_mem[i];
        fd=$fopen("small1_results.csv","w"); $fwrite(fd,"direction"); for(i=0;i<16;i=i+1)$fwrite(fd,",x%0d",i); $fwrite(fd,"\n");
        repeat(2) @(negedge clk); rst=0;
        inverse=0; start=1; @(negedge clk); start=0; wait(valid_out==1'b1); #0.1;
        $fwrite(fd,"forward"); for(i=0;i<16;i=i+1)$fwrite(fd,",%0d",dout[i*14 +: 14]); $fwrite(fd,"\n"); @(negedge clk);
        din=dout; inverse=1; start=1; @(negedge clk); start=0; wait(valid_out==1'b1); #0.1;
        $fwrite(fd,"inverse"); for(i=0;i<16;i=i+1)$fwrite(fd,",%0d",dout[i*14 +: 14]); $fwrite(fd,"\n");
        $fclose(fd); $finish;
    end
endmodule
