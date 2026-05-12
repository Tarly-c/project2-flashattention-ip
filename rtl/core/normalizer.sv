`timescale 1ns/1ps

module normalizer #(
    parameter int ACC_W  = 48,
    parameter int L_W    = 48,
    parameter int DATA_W = 16
) (
    input  logic signed [ACC_W-1:0] acc,
    input  logic [L_W-1:0] denom,
    output logic signed [DATA_W-1:0] out
);
    logic signed [ACC_W-1:0] quotient;
    logic signed [DATA_W-1:0] saturated;

    quantize_saturate #(
        .IN_W(ACC_W),
        .OUT_W(DATA_W)
    ) u_quantize_saturate (
        .value(quotient),
        .result(saturated)
    );

    always_comb begin
        if (denom == '0) begin
            quotient = '0;
        end else begin
            quotient = acc / $signed({1'b0, denom});
        end
        out = saturated;
    end
endmodule
