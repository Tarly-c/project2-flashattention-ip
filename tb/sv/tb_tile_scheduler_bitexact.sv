`timescale 1ns/1ps

module tb_tile_scheduler_bitexact;
    localparam int S_LEN = 5;
    localparam int BK    = 2;
    localparam int ROW_W = $clog2(S_LEN);
    localparam int LEN_W = $clog2(BK + 1);

    logic clk;
    logic rst_n;
    logic start;
    logic step;
    logic valid;
    logic done;
    logic [ROW_W-1:0] row_index;
    logic [ROW_W-1:0] kv_start;
    logic [LEN_W-1:0] kv_len;
    logic first_tile;
    logic last_tile;
    logic last_row;

    tile_scheduler #(
        .S_LEN(S_LEN),
        .BK(BK)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .step(step),
        .valid(valid),
        .done(done),
        .row_index(row_index),
        .kv_start(kv_start),
        .kv_len(kv_len),
        .first_tile(first_tile),
        .last_tile(last_tile),
        .last_row(last_row)
    );

    always #5 clk = ~clk;

    task automatic pulse_step;
        begin
            @(negedge clk);
            step = 1'b1;
            @(negedge clk);
            step = 1'b0;
        end
    endtask

    task automatic expect_tuple(
        input logic [ROW_W-1:0] expected_row,
        input logic [ROW_W-1:0] expected_kv_start,
        input logic [LEN_W-1:0] expected_kv_len,
        input logic expected_first,
        input logic expected_last_tile,
        input logic expected_last_row
    );
        begin
            @(posedge clk);
            #1;
            if (valid !== 1'b1 ||
                row_index !== expected_row ||
                kv_start !== expected_kv_start ||
                kv_len !== expected_kv_len ||
                first_tile !== expected_first ||
                last_tile !== expected_last_tile ||
                last_row !== expected_last_row) begin
                $display("FAIL scheduler got valid=%b row=%0d kv=%0d len=%0d first=%b last_tile=%b last_row=%b",
                         valid, row_index, kv_start, kv_len, first_tile, last_tile, last_row);
                $display("FAIL scheduler expected row=%0d kv=%0d len=%0d first=%b last_tile=%b last_row=%b",
                         expected_row, expected_kv_start, expected_kv_len,
                         expected_first, expected_last_tile, expected_last_row);
                $fatal(1);
            end
            $display("PASS scheduler row=%0d kv=%0d len=%0d", row_index, kv_start, kv_len);
        end
    endtask

    initial begin
        $dumpfile("tb_tile_scheduler_bitexact.vcd");
        $dumpvars(0, tb_tile_scheduler_bitexact);

        clk   = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        step  = 1'b0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        expect_tuple(3'd0, 3'd0, 2'd2, 1'b1, 1'b0, 1'b0);
        pulse_step();
        expect_tuple(3'd0, 3'd2, 2'd2, 1'b0, 1'b0, 1'b0);
        pulse_step();
        expect_tuple(3'd0, 3'd4, 2'd1, 1'b0, 1'b1, 1'b0);
        pulse_step();
        expect_tuple(3'd1, 3'd0, 2'd2, 1'b1, 1'b0, 1'b0);
        pulse_step();
        expect_tuple(3'd1, 3'd2, 2'd2, 1'b0, 1'b0, 1'b0);
        pulse_step();
        expect_tuple(3'd1, 3'd4, 2'd1, 1'b0, 1'b1, 1'b0);
        pulse_step();
        expect_tuple(3'd2, 3'd0, 2'd2, 1'b1, 1'b0, 1'b0);
        pulse_step();
        expect_tuple(3'd2, 3'd2, 2'd2, 1'b0, 1'b0, 1'b0);
        pulse_step();
        expect_tuple(3'd2, 3'd4, 2'd1, 1'b0, 1'b1, 1'b0);
        pulse_step();
        expect_tuple(3'd3, 3'd0, 2'd2, 1'b1, 1'b0, 1'b0);
        pulse_step();
        expect_tuple(3'd3, 3'd2, 2'd2, 1'b0, 1'b0, 1'b0);
        pulse_step();
        expect_tuple(3'd3, 3'd4, 2'd1, 1'b0, 1'b1, 1'b0);
        pulse_step();
        expect_tuple(3'd4, 3'd0, 2'd2, 1'b1, 1'b0, 1'b1);
        pulse_step();
        expect_tuple(3'd4, 3'd2, 2'd2, 1'b0, 1'b0, 1'b1);
        pulse_step();
        expect_tuple(3'd4, 3'd4, 2'd1, 1'b0, 1'b1, 1'b1);
        pulse_step();

        #1;
        if (valid !== 1'b0 || done !== 1'b1) begin
            $display("FAIL scheduler final valid=%b done=%b", valid, done);
            $fatal(1);
        end

        $display("tb_tile_scheduler_bitexact PASS");
        $finish;
    end
endmodule
