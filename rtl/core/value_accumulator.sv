`timescale 1ns/1ps

module value_accumulator #(
    parameter int D_MODEL     = 64,
    parameter int DATA_W      = 16,
    parameter int ACC_W       = 48,
    parameter int WEIGHT_W    = 16,
    parameter int WEIGHT_FRAC = 8
) (
    input  logic signed [ACC_W-1:0] acc_in [0:D_MODEL-1],
    input  logic signed [DATA_W-1:0] v_data [0:D_MODEL-1],
    input  logic [WEIGHT_W-1:0] old_scale,
    input  logic [WEIGHT_W-1:0] new_weight,

    output wire signed [ACC_W-1:0] acc_out [0:D_MODEL-1]
);
    genvar d;

    function automatic logic signed [ACC_W-1:0] update_one(
        input logic signed [ACC_W-1:0] acc_value,
        input logic signed [DATA_W-1:0] v_value,
        input logic [WEIGHT_W-1:0] scale_old,
        input logic [WEIGHT_W-1:0] weight_new
    );
        logic signed [ACC_W+WEIGHT_W:0] old_term;
        logic signed [DATA_W+WEIGHT_W:0] new_term;
        logic signed [ACC_W+WEIGHT_W+1:0] sum_term;
        begin
            old_term = (acc_value * $signed({1'b0, scale_old})) >>> WEIGHT_FRAC;
            new_term = $signed({1'b0, weight_new}) * v_value;
            sum_term = old_term + new_term;
            update_one = sum_term[ACC_W-1:0];
        end
    endfunction

    generate
        for (d = 0; d < D_MODEL; d = d + 1) begin : gen_acc_update
            assign acc_out[d] = update_one(acc_in[d], v_data[d], old_scale, new_weight);
        end
    endgenerate
endmodule
