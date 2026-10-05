`timescale 1ns/1ps
module tb_stream_blocks_roundtrip;
    reg clk = 0, rst = 1;
    reg in_valid = 0, in_sof = 0;
    reg [13:0] din = 0;
    wire block_start;
    wire [223:0] block_data;
    reg out_start = 0;
    wire out_valid;
    wire [3:0] out_index;
    wire [13:0] dout;
    integer i, errors, seen, fd;
    reg [13:0] expected [0:15];

    always #1 clk = ~clk;

    stream_to_block16 u_in(
        .clk(clk), .rst(rst), .in_valid(in_valid), .in_sof(in_sof),
        .din(din), .block_start(block_start), .block_data(block_data)
    );
    block_to_stream16 u_out(
        .clk(clk), .rst(rst), .start(out_start), .block_data(block_data),
        .out_valid(out_valid), .index(out_index), .dout(dout)
    );

    initial begin
        errors = 0;
        seen = 0;
        fd = $fopen("stream_roundtrip.csv", "w");
        $fwrite(fd, "index,input,output\n");
        repeat (2) @(negedge clk);
        rst = 0;

        for (i = 0; i < 16; i = i + 1) begin
            @(negedge clk);
            din = 14'd100 + i;
            expected[i] = 14'd100 + i;
            in_sof = (i == 0);
            in_valid = 1;
        end
        @(negedge clk);
        in_valid = 0;
        in_sof = 0;

        if (!block_start) begin
            $display("FAIL block_start");
            $finish;
        end
        for (i = 0; i < 16; i = i + 1)
            if (block_data[i*14 +: 14] !== expected[i]) errors = errors + 1;

        @(negedge clk);
        out_start = 1;
        @(negedge clk);
        out_start = 0;
        while (seen < 16) begin
            @(negedge clk);
            if (out_valid) begin
                $fwrite(fd, "%0d,%0d,%0d\n", seen, expected[seen], dout);
                if (dout !== expected[seen]) errors = errors + 1;
                seen = seen + 1;
            end
        end
        $fclose(fd);
        if (errors == 0) $display("PASS stream_roundtrip samples=16 errors=0");
        else $display("FAIL stream_roundtrip samples=%0d errors=%0d", seen, errors);
        $finish;
    end
endmodule



