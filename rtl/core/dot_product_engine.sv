`timescale 1ns/1ps

module dot_product_engine #(
    parameter int D_MODEL = 64,
    parameter int DATA_W  = 16,
    parameter int ACC_W   = 48
) (
    input  logic clk,
    input  logic rst_n,

    input  logic start,
    input  logic signed [DATA_W-1:0] q_vec [0:D_MODEL-1],
    input  logic signed [DATA_W-1:0] k_vec [0:D_MODEL-1],

    output logic busy,
    output logic done,
    output logic signed [ACC_W-1:0] dot
);
    localparam int IDX_W = (D_MODEL <= 1) ? 1 : $clog2(D_MODEL);
    localparam int PROD_W = DATA_W * 2;

    logic [IDX_W-1:0] index_q;
    logic signed [ACC_W-1:0] acc_q;
    logic signed [PROD_W-1:0] product;

    assign product = q_vec[index_q] * k_vec[index_q];

    function automatic logic signed [ACC_W-1:0] extend_product(
        input logic signed [PROD_W-1:0] value
    );
        begin
            extend_product = {{(ACC_W-PROD_W){value[PROD_W-1]}}, value};
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy    <= 1'b0;
            done    <= 1'b0;
            dot     <= '0;
            acc_q   <= '0;
            index_q <= '0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                busy    <= 1'b1;
                acc_q   <= '0;
                index_q <= '0;
                dot     <= '0;
            end else if (busy) begin
                if (index_q == D_MODEL - 1) begin
                    dot     <= acc_q + extend_product(product);
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    acc_q   <= '0;
                    index_q <= '0;
                end else begin
                    acc_q   <= acc_q + extend_product(product);
                    index_q <= index_q + 1'b1;
                end
            end
        end
    end
endmodule
