`timescale 1ns/1ps

module row_buffer #(
    parameter int D_MODEL = 64,
    parameter int DATA_W  = 16
) (
    input  logic clk,
    input  logic rst_n,

    input  logic clear,
    input  logic load_valid,
    output logic load_ready,
    input  logic signed [DATA_W-1:0] load_data [0:D_MODEL-1],

    output logic valid,
    output wire signed [DATA_W-1:0] row_data [0:D_MODEL-1]
);
    logic signed [DATA_W-1:0] row_data_q [0:D_MODEL-1];
    int d;
    genvar row_gen;

    assign load_ready = 1'b1;

    generate
        for (row_gen = 0; row_gen < D_MODEL; row_gen = row_gen + 1) begin : gen_row_data_assign
            assign row_data[row_gen] = row_data_q[row_gen];
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
            for (d = 0; d < D_MODEL; d = d + 1) begin
                row_data_q[d] <= '0;
            end
        end else if (clear) begin
            valid <= 1'b0;
        end else if (load_valid) begin
            valid <= 1'b1;
            for (d = 0; d < D_MODEL; d = d + 1) begin
                row_data_q[d] <= load_data[d];
            end
        end
    end
endmodule
