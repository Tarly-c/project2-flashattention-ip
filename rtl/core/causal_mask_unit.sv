`timescale 1ns/1ps

module causal_mask_unit #(
    parameter int S_LEN   = 256,
    parameter int SCORE_W = 48
) (
    input  logic causal_en,
    input  logic [$clog2(S_LEN)-1:0] query_index,
    input  logic [$clog2(S_LEN)-1:0] key_index,
    input  logic signed [SCORE_W-1:0] score_in,
    input  logic signed [31:0] neg_large,

    output logic score_valid,
    output logic signed [SCORE_W-1:0] score_out
);
    logic masked_q;
    logic signed [SCORE_W-1:0] neg_large_ext;

    assign masked_q = causal_en && (key_index > query_index);
    assign neg_large_ext = {{(SCORE_W-32){neg_large[31]}}, neg_large};

    always_comb begin
        score_valid = !masked_q;
        score_out   = masked_q ? neg_large_ext : score_in;
    end
endmodule
