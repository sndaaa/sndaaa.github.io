`timescale 1ns/1ps

// Scalable reference core for N=16/64/256. It reuses one modular multiplier
// over time, so it is easy to verify and resource-light, while fnt16_pipeline.v
// remains the high-throughput fully-unrolled option.
module fnt_seq_core #(
    parameter MAX_N=256
)(
    input clk,input rst,input start,input inverse,input [1:0] point_sel,
    input [MAX_N*14-1:0] din,
    output reg done,output reg busy,output reg [MAX_N*14-1:0] dout
);
    localparam integer Q=12289;
    localparam [2:0] IDLE=0,CALC=1,OUTPUT=2;
    reg [13:0] mem[0:MAX_N-1],out_mem[0:MAX_N-1];
    reg [2:0] state; reg [8:0] n_reg,k_idx,n_idx; reg inv_reg;
    reg [13:0] root_reg,inv_root_reg,n_inv_reg;
    integer i,acc,prod,next_sum,exp_idx;
    function integer n_for; input [1:0] s; begin case(s) 2'd0:n_for=16;2'd1:n_for=64;default:n_for=256;endcase end endfunction
    function integer root_for; input [1:0] s; begin case(s) 2'd0:root_for=4134;2'd1:root_for=7311;default:root_for=8340;endcase end endfunction
    function integer invroot_for; input [1:0] s; begin case(s) 2'd0:invroot_for=10984;2'd1:invroot_for=9650;default:invroot_for=1696;endcase end endfunction
    function integer n_inv_for; input [1:0] s; begin case(s) 2'd0:n_inv_for=11521;2'd1:n_inv_for=12097;default:n_inv_for=12241;endcase end endfunction
    function integer madd; input integer a,b; integer t; begin t=a+b;if(t>=Q)t=t-Q;madd=t;end endfunction
    function integer mmul; input integer a,b; integer t; begin t=(a*b)%Q;if(t<0)t=t+Q;mmul=t;end endfunction
    function integer mpow; input integer a,e; integer k,t,x; begin x=a;t=1;for(k=0;k<16;k=k+1)begin if((e>>k)&1)t=mmul(t,x);x=mmul(x,x);end mpow=t;end endfunction
    always @(posedge clk) begin
        done<=0;
        if(rst) begin state<=IDLE;busy<=0;n_reg<=0;k_idx<=0;n_idx<=0;acc<=0;dout<=0;inv_reg<=0;root_reg<=0;inv_root_reg<=0;n_inv_reg<=0;end
        else case(state)
            IDLE: begin
                if(start) begin
                    n_reg<=n_for(point_sel);root_reg<=root_for(point_sel);inv_root_reg<=invroot_for(point_sel);n_inv_reg<=n_inv_for(point_sel);inv_reg<=inverse;
                    for(i=0;i<MAX_N;i=i+1) begin if(i<n_for(point_sel))mem[i]<=din[i*14 +: 14]; else mem[i]<=0; end
                    k_idx<=0;n_idx<=0;acc<=0;busy<=1;state<=CALC;
                end
            end
            CALC: begin
                exp_idx=(k_idx*n_idx)%n_reg;
                prod=mmul(mem[n_idx],mpow(inv_reg?inv_root_reg:root_reg,exp_idx));
                next_sum=madd(acc,prod);
                if(n_idx==n_reg-1) begin
                    if(inv_reg)out_mem[k_idx]<=mmul(next_sum,n_inv_reg);else out_mem[k_idx]<=next_sum;
                    acc<=0;n_idx<=0;
                    if(k_idx==n_reg-1)state<=OUTPUT;else k_idx<=k_idx+1'b1;
                end else begin acc<=next_sum;n_idx<=n_idx+1'b1;end
            end
            OUTPUT: begin
                for(i=0;i<MAX_N;i=i+1)begin if(i<n_reg)dout[i*14 +: 14]<=out_mem[i];else dout[i*14 +: 14]<=0;end
                done<=1;busy<=0;state<=IDLE;
            end
            default: state<=IDLE;
        endcase
    end
endmodule
