`timescale 1ns/1ps

module online_softmax_engine #(
    parameter int SCORE_W     = 48,
    parameter int L_W         = 48,
    parameter int WEIGHT_W    = 16,
    parameter int WEIGHT_FRAC = 8
) (
    input  logic score_valid,
    input  logic signed [SCORE_W-1:0] score,
    input  logic signed [SCORE_W-1:0] m_in,
    input  logic [L_W-1:0] l_in,

    output logic signed [SCORE_W-1:0] m_out,
    output logic [L_W-1:0] l_out,
    output logic [WEIGHT_W-1:0] old_scale,
    output logic [WEIGHT_W-1:0] new_weight
);
    localparam logic [WEIGHT_W-1:0] WEIGHT_ONE = (1 << WEIGHT_FRAC);

    function automatic logic [WEIGHT_W-1:0] exp_approx_weight(
        input logic signed [SCORE_W-1:0] delta
    );
        logic [SCORE_W-1:0] abs_delta;
        logic [SCORE_W+WEIGHT_FRAC:0] numerator;
        logic [SCORE_W+WEIGHT_FRAC:0] denominator;
        logic [SCORE_W+WEIGHT_FRAC:0] quotient;
        begin
            if (delta[SCORE_W-1] == 1'b0) begin
                exp_approx_weight = WEIGHT_ONE;
            end else begin
                abs_delta = -delta;
                numerator = (1 << (2 * WEIGHT_FRAC));
                denominator = (1 << WEIGHT_FRAC) + abs_delta;
                quotient = numerator / denominator;

                if (quotient > WEIGHT_ONE) begin
                    exp_approx_weight = WEIGHT_ONE;
                end else begin
                    exp_approx_weight = quotient[WEIGHT_W-1:0];
                end
            end
        end
    endfunction

    function automatic logic [L_W-1:0] update_l(
        input logic [L_W-1:0] old_l,
        input logic [WEIGHT_W-1:0] scale_old,
        input logic [WEIGHT_W-1:0] weight_new
    );
        logic [L_W+WEIGHT_W:0] scaled_l;
        logic [L_W+WEIGHT_W:0] sum_l;
        begin
            scaled_l = (old_l * scale_old) >> WEIGHT_FRAC;
            sum_l = scaled_l + weight_new;
            update_l = sum_l[L_W-1:0];
        end
    endfunction

    always @* begin
        m_out      = m_in;
        l_out      = l_in;
        old_scale  = WEIGHT_ONE;
        new_weight = '0;

        if (score_valid) begin
            if (l_in == '0) begin
                m_out      = score;
                l_out      = WEIGHT_ONE;
                old_scale  = '0;
                new_weight = WEIGHT_ONE;
            end else if (score > m_in) begin
                m_out      = score;
                old_scale  = exp_approx_weight(m_in - score);
                new_weight = WEIGHT_ONE;
                l_out      = update_l(l_in, old_scale, new_weight);
            end else begin
                m_out      = m_in;
                old_scale  = WEIGHT_ONE;
                new_weight = exp_approx_weight(score - m_in);
                l_out      = update_l(l_in, old_scale, new_weight);
            end
        end
    end
endmodule
