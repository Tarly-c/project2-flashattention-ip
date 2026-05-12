`timescale 1ns/1ps

module tb_flash_core_smoke;
    localparam int S_LEN   = 4;
    localparam int D_MODEL = 4;
    localparam int BK      = 2;
    localparam int DATA_W  = 16;
    localparam int ACC_W   = 48;

    logic clk;
    logic rst_n;
    logic start;
    logic busy;
    logic done;
    logic error;
    logic causal_en;
    logic signed [31:0] neg_large;
    logic signed [31:0] scale;

    logic q_req_valid;
    logic [$clog2(S_LEN)-1:0] q_req_row;
    logic q_req_ready;
    logic q_data_valid;
    logic signed [DATA_W-1:0] q_data [0:D_MODEL-1];
    logic q_data_ready;

    logic kv_req_valid;
    logic [$clog2(S_LEN)-1:0] kv_req_start;
    logic [$clog2(BK+1)-1:0] kv_req_len;
    logic kv_req_ready;
    logic kv_data_valid;
    logic signed [DATA_W-1:0] k_tile [0:BK-1][0:D_MODEL-1];
    logic signed [DATA_W-1:0] v_tile [0:BK-1][0:D_MODEL-1];
    logic kv_data_ready;

    logic o_valid;
    logic [$clog2(S_LEN)-1:0] o_row;
    wire signed [DATA_W-1:0] o_data [0:D_MODEL-1];
    logic o_ready;

    int d;
    int b;
    int output_rows;

    flash_core #(
        .S_LEN(S_LEN),
        .D_MODEL(D_MODEL),
        .BK(BK),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .busy(busy),
        .done(done),
        .error(error),
        .causal_en(causal_en),
        .neg_large(neg_large),
        .scale(scale),
        .q_req_valid(q_req_valid),
        .q_req_row(q_req_row),
        .q_req_ready(q_req_ready),
        .q_data_valid(q_data_valid),
        .q_data(q_data),
        .q_data_ready(q_data_ready),
        .kv_req_valid(kv_req_valid),
        .kv_req_start(kv_req_start),
        .kv_req_len(kv_req_len),
        .kv_req_ready(kv_req_ready),
        .kv_data_valid(kv_data_valid),
        .k_tile(k_tile),
        .v_tile(v_tile),
        .kv_data_ready(kv_data_ready),
        .o_valid(o_valid),
        .o_row(o_row),
        .o_data(o_data),
        .o_ready(o_ready)
    );

    always #5 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q_data_valid  <= 1'b0;
            kv_data_valid <= 1'b0;
            output_rows   <= 0;
            for (d = 0; d < D_MODEL; d = d + 1) begin
                q_data[d] <= '0;
            end
            for (b = 0; b < BK; b = b + 1) begin
                for (d = 0; d < D_MODEL; d = d + 1) begin
                    k_tile[b][d] <= '0;
                    v_tile[b][d] <= '0;
                end
            end
        end else begin
            q_data_valid  <= 1'b0;
            kv_data_valid <= 1'b0;

            if (q_req_valid && q_req_ready) begin
                $display("Q request row=%0d", q_req_row);
                for (d = 0; d < D_MODEL; d = d + 1) begin
                    q_data[d] <= $signed({1'b0, q_req_row}) + d + 1;
                end
                q_data_valid <= 1'b1;
            end

            if (q_data_valid && q_data_ready) begin
                $display("Q data accepted q0=%0d", q_data[0]);
            end

            if (kv_req_valid && kv_req_ready) begin
                $display("KV request start=%0d len=%0d", kv_req_start, kv_req_len);
                for (b = 0; b < BK; b = b + 1) begin
                    for (d = 0; d < D_MODEL; d = d + 1) begin
                        k_tile[b][d] <= $signed({1'b0, kv_req_start}) + b + d + 1;
                        v_tile[b][d] <= $signed({1'b0, kv_req_start}) + b + d + 2;
                    end
                end
                kv_data_valid <= 1'b1;
            end

            if (kv_data_valid && kv_data_ready) begin
                $display("KV data accepted k00=%0d", k_tile[0][0]);
            end

            if (o_valid && o_ready) begin
                if ($isunknown(o_data[0])) begin
                    $display("FAIL O row %0d first word is unknown", o_row);
                    $fatal(1);
                end
                output_rows <= output_rows + 1;
                $display("O row %0d first_word=%0d", o_row, o_data[0]);
            end
        end
    end

    initial begin
        $dumpfile("tb_flash_core_smoke.vcd");
        $dumpvars(0, tb_flash_core_smoke);

        clk          = 1'b0;
        rst_n        = 1'b0;
        start        = 1'b0;
        causal_en    = 1'b0;
        neg_large    = -32'sd32768;
        scale        = 32'sd32;
        q_req_ready  = 1'b1;
        kv_req_ready = 1'b1;
        o_ready      = 1'b1;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        fork
            begin
                wait (done);
            end
            begin
                repeat (300) @(posedge clk);
                $display("FAIL timeout waiting for flash_core done");
                $fatal(1);
            end
        join_any
        disable fork;

        @(posedge clk);
        if (error) begin
            $display("FAIL core error asserted");
            $fatal(1);
        end
        if (output_rows != S_LEN) begin
            $display("FAIL output_rows=%0d expected=%0d", output_rows, S_LEN);
            $fatal(1);
        end

        $display("tb_flash_core_smoke PASS");
        $finish;
    end
endmodule
