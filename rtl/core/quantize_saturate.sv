`timescale 1ns/1ps

module quantize_saturate #(
    parameter int IN_W  = 48,
    parameter int OUT_W = 16
) (
    input  logic signed [IN_W-1:0] value,
    output logic signed [OUT_W-1:0] result
);
    logic signed [IN_W-1:0] max_value;
    logic signed [IN_W-1:0] min_value;

    always @* begin
        max_value = (1 <<< (OUT_W - 1)) - 1;
        min_value = -(1 <<< (OUT_W - 1));

        if (value > max_value) begin
            result = max_value[OUT_W-1:0];
        end else if (value < min_value) begin
            result = min_value[OUT_W-1:0];
        end else begin
            result = value[OUT_W-1:0];
        end
    end
endmodule
