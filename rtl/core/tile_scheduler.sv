`timescale 1ns/1ps

module tile_scheduler #(
    parameter int S_LEN = 256,
    parameter int BK    = 16
) (
    input  logic clk,
    input  logic rst_n,

    input  logic start,
    input  logic step,

    output logic valid,
    output logic done,
    output logic [$clog2(S_LEN)-1:0] row_index,
    output logic [$clog2(S_LEN)-1:0] kv_start,
    output logic [$clog2(BK+1)-1:0]  kv_len,
    output logic first_tile,
    output logic last_tile,
    output logic last_row
);
    localparam int ROW_W = (S_LEN <= 1) ? 1 : $clog2(S_LEN);
    localparam int LEN_W = (BK <= 1) ? 1 : $clog2(BK + 1);

    function automatic logic [LEN_W-1:0] calc_len(input logic [ROW_W-1:0] start_index);
        int remaining;
        begin
            remaining = S_LEN - start_index;
            if (remaining > BK) begin
                calc_len = BK[LEN_W-1:0];
            end else begin
                calc_len = remaining[LEN_W-1:0];
            end
        end
    endfunction

    assign first_tile = valid && (kv_start == '0);
    assign last_tile  = valid && ((kv_start + BK) >= S_LEN);
    assign last_row   = valid && (row_index == S_LEN - 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid     <= 1'b0;
            done      <= 1'b0;
            row_index <= '0;
            kv_start  <= '0;
            kv_len    <= '0;
        end else begin
            done <= 1'b0;

            if (start) begin
                valid     <= 1'b1;
                row_index <= '0;
                kv_start  <= '0;
                kv_len    <= calc_len('0);
            end else if (valid && step) begin
                if (last_tile && last_row) begin
                    valid <= 1'b0;
                    done  <= 1'b1;
                end else if (last_tile) begin
                    row_index <= row_index + 1'b1;
                    kv_start  <= '0;
                    kv_len    <= calc_len('0);
                end else begin
                    kv_start <= kv_start + BK[ROW_W-1:0];
                    kv_len   <= calc_len(kv_start + BK[ROW_W-1:0]);
                end
            end
        end
    end
endmodule
