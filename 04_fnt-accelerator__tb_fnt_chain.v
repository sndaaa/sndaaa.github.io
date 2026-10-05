`timescale 1ns/1ps
module tb_fnt_chain;
    parameter B=16;
    reg clk=0,rst=1,start=0,bypass=0,cfg_we=0; reg [3:0] cfg_addr; reg [13:0] cfg_data; reg [223:0] din;
    reg [223:0] blocks[0:B-1]; reg [13:0] lut[0:15]; wire valid_out; wire [223:0] dout; integer i,j,fd;
    always #1 clk=~clk;
    fnt_chain_top dut(clk,rst,start,bypass,cfg_we,cfg_addr,cfg_data,din,valid_out,dout);
    initial begin
        $readmemh("chain_vectors.mem",blocks); $readmemh("comp_lut.mem",lut); fd=$fopen("chain_results.csv","w"); $fwrite(fd,"block"); for(j=0;j<16;j=j+1)$fwrite(fd,",y%0d",j); $fwrite(fd,"\n");
        repeat(2) @(negedge clk); rst=0;
        for(i=0;i<16;i=i+1) begin cfg_addr=i;cfg_data=lut[i];cfg_we=1;@(negedge clk);cfg_we=0;@(negedge clk);end
        for(i=0;i<B;i=i+1) begin
            din=blocks[i];start=1;@(negedge clk);start=0;wait(valid_out==1'b1);#0.1;$fwrite(fd,"%0d",i);for(j=0;j<16;j=j+1)$fwrite(fd,",%0d",dout[j*14 +: 14]);$fwrite(fd,"\n");@(negedge clk);
        end
        $fclose(fd);$finish;
    end
endmodule
