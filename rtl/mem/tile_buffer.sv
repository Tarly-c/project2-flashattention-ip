`timescale 1ns/1ps

module tile_buffer #(
    parameter int BK      = 16,
    parameter int D_MODEL = 64,
    parameter int DATA_W  = 16
) (
    input  logic clk,
    input  logic rst_n,

    input  logic clear,
    input  logic load_valid,
    output logic load_ready,
    input  logic signed [DATA_W-1:0] k_load [0:BK-1][0:D_MODEL-1],
    input  logic signed [DATA_W-1:0] v_load [0:BK-1][0:D_MODEL-1],

    output logic valid,
    output wire signed [DATA_W-1:0] k_data [0:BK-1][0:D_MODEL-1],
    output wire signed [DATA_W-1:0] v_data [0:BK-1][0:D_MODEL-1]
);
    logic signed [DATA_W-1:0] k_data_q [0:BK-1][0:D_MODEL-1];
    logic signed [DATA_W-1:0] v_data_q [0:BK-1][0:D_MODEL-1];
    int b;
    int d;
    genvar tile_b;
    genvar tile_d;

    assign load_ready = 1'b1;

    generate
        for (tile_b = 0; tile_b < BK; tile_b = tile_b + 1) begin : gen_tile_row_assign
            for (tile_d = 0; tile_d < D_MODEL; tile_d = tile_d + 1) begin : gen_tile_col_assign
                assign k_data[tile_b][tile_d] = k_data_q[tile_b][tile_d];
                assign v_data[tile_b][tile_d] = v_data_q[tile_b][tile_d];
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
            for (b = 0; b < BK; b = b + 1) begin
                for (d = 0; d < D_MODEL; d = d + 1) begin
                    k_data_q[b][d] <= '0;
                    v_data_q[b][d] <= '0;
                end
            end
        end else if (clear) begin
            valid <= 1'b0;
        end else if (load_valid) begin
            valid <= 1'b1;
            for (b = 0; b < BK; b = b + 1) begin
                for (d = 0; d < D_MODEL; d = d + 1) begin
                    k_data_q[b][d] <= k_load[b][d];
                    v_data_q[b][d] <= v_load[b][d];
                end
            end
        end
    end
endmodule
