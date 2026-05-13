`timescale 1ns/1ps

module tb_buffers_bitexact;
    localparam int D_MODEL = 4;
    localparam int BK      = 2;
    localparam int DATA_W  = 16;

    logic clk;
    logic rst_n;
    logic clear;

    logic row_load_valid;
    logic row_load_ready;
    logic signed [DATA_W-1:0] row_load_data [0:D_MODEL-1];
    logic row_valid;
    wire signed [DATA_W-1:0] row_data [0:D_MODEL-1];

    logic tile_load_valid;
    logic tile_load_ready;
    logic signed [DATA_W-1:0] k_load [0:BK-1][0:D_MODEL-1];
    logic signed [DATA_W-1:0] v_load [0:BK-1][0:D_MODEL-1];
    logic tile_valid;
    wire signed [DATA_W-1:0] k_data [0:BK-1][0:D_MODEL-1];
    wire signed [DATA_W-1:0] v_data [0:BK-1][0:D_MODEL-1];

    int b;
    int d;

    row_buffer #(
        .D_MODEL(D_MODEL),
        .DATA_W(DATA_W)
    ) u_row_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),
        .load_valid(row_load_valid),
        .load_ready(row_load_ready),
        .load_data(row_load_data),
        .valid(row_valid),
        .row_data(row_data)
    );

    tile_buffer #(
        .BK(BK),
        .D_MODEL(D_MODEL),
        .DATA_W(DATA_W)
    ) u_tile_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),
        .load_valid(tile_load_valid),
        .load_ready(tile_load_ready),
        .k_load(k_load),
        .v_load(v_load),
        .valid(tile_valid),
        .k_data(k_data),
        .v_data(v_data)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_buffers_bitexact.vcd");
        $dumpvars(0, tb_buffers_bitexact);

        clk = 1'b0;
        rst_n = 1'b0;
        clear = 1'b0;
        row_load_valid = 1'b0;
        tile_load_valid = 1'b0;

        for (d = 0; d < D_MODEL; d = d + 1) begin
            row_load_data[d] = '0;
        end
        for (b = 0; b < BK; b = b + 1) begin
            for (d = 0; d < D_MODEL; d = d + 1) begin
                k_load[b][d] = '0;
                v_load[b][d] = '0;
            end
        end

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        row_load_data[0] = 16'h1234;
        row_load_data[1] = -16'sd7;
        row_load_data[2] = 16'h55aa;
        row_load_data[3] = 16'h7fff;
        row_load_valid = 1'b1;
        @(negedge clk);
        row_load_valid = 1'b0;

        @(posedge clk);
        #1;
        if (row_valid !== 1'b1 || row_load_ready !== 1'b1) begin
            $display("FAIL row buffer valid/ready row_valid=%b row_ready=%b",
                     row_valid, row_load_ready);
            $fatal(1);
        end
        for (d = 0; d < D_MODEL; d = d + 1) begin
            if (row_data[d] !== row_load_data[d]) begin
                $display("FAIL row_buffer[%0d] got=%04h expected=%04h",
                         d, row_data[d], row_load_data[d]);
                $fatal(1);
            end
        end

        @(negedge clk);
        for (b = 0; b < BK; b = b + 1) begin
            for (d = 0; d < D_MODEL; d = d + 1) begin
                k_load[b][d] = 16'(16'h0100 + b * 16 + d);
                v_load[b][d] = 16'(16'h0200 + b * 16 + d);
            end
        end
        tile_load_valid = 1'b1;
        @(negedge clk);
        tile_load_valid = 1'b0;

        @(posedge clk);
        #1;
        if (tile_valid !== 1'b1 || tile_load_ready !== 1'b1) begin
            $display("FAIL tile buffer valid/ready tile_valid=%b tile_ready=%b",
                     tile_valid, tile_load_ready);
            $fatal(1);
        end
        for (b = 0; b < BK; b = b + 1) begin
            for (d = 0; d < D_MODEL; d = d + 1) begin
                if (k_data[b][d] !== k_load[b][d]) begin
                    $display("FAIL k_data[%0d][%0d] got=%04h expected=%04h",
                             b, d, k_data[b][d], k_load[b][d]);
                    $fatal(1);
                end
                if (v_data[b][d] !== v_load[b][d]) begin
                    $display("FAIL v_data[%0d][%0d] got=%04h expected=%04h",
                             b, d, v_data[b][d], v_load[b][d]);
                    $fatal(1);
                end
            end
        end

        @(negedge clk);
        clear = 1'b1;
        @(negedge clk);
        clear = 1'b0;
        @(posedge clk);
        #1;
        if (row_valid !== 1'b0 || tile_valid !== 1'b0) begin
            $display("FAIL clear row_valid=%b tile_valid=%b", row_valid, tile_valid);
            $fatal(1);
        end

        $display("tb_buffers_bitexact PASS");
        $finish;
    end
endmodule
