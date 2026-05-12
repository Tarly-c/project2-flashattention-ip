`timescale 1ns/1ps

module flash_core #(
    parameter int S_LEN   = 256,
    parameter int D_MODEL = 64,
    parameter int BK      = 16,
    parameter int DATA_W  = 16,
    parameter int ACC_W   = 48,
    parameter int FRAC_W  = 8
) (
    input  logic clk,
    input  logic rst_n,

    input  logic start,
    output logic busy,
    output logic done,
    output logic error,

    input  logic causal_en,
    input  logic signed [31:0] neg_large,
    input  logic signed [31:0] scale,

    output logic q_req_valid,
    output logic [$clog2(S_LEN)-1:0] q_req_row,
    input  logic q_req_ready,

    input  logic q_data_valid,
    input  logic signed [DATA_W-1:0] q_data [0:D_MODEL-1],
    output logic q_data_ready,

    output logic kv_req_valid,
    output logic [$clog2(S_LEN)-1:0] kv_req_start,
    output logic [$clog2(BK+1)-1:0]  kv_req_len,
    input  logic kv_req_ready,

    input  logic kv_data_valid,
    input  logic signed [DATA_W-1:0] k_tile [0:BK-1][0:D_MODEL-1],
    input  logic signed [DATA_W-1:0] v_tile [0:BK-1][0:D_MODEL-1],
    output logic kv_data_ready,

    output logic o_valid,
    output logic [$clog2(S_LEN)-1:0] o_row,
    output wire signed [DATA_W-1:0] o_data [0:D_MODEL-1],
    input  logic o_ready
);
    localparam int ROW_W = (S_LEN <= 1) ? 1 : $clog2(S_LEN);
    localparam int LEN_W = (BK <= 1) ? 1 : $clog2(BK + 1);

    typedef enum logic [3:0] {
        ST_IDLE,
        ST_REQ_Q,
        ST_WAIT_Q,
        ST_REQ_KV,
        ST_WAIT_KV,
        ST_DOT_START,
        ST_DOT_WAIT,
        ST_EMIT_O,
        ST_STEP,
        ST_DONE
    } state_t;

    state_t state_q;

    logic sched_start;
    logic sched_step;
    logic sched_valid;
    logic sched_done;
    logic [ROW_W-1:0] sched_row;
    logic [ROW_W-1:0] sched_kv_start;
    logic [LEN_W-1:0] sched_kv_len;
    logic sched_last_tile;
    logic sched_last_row;

    logic signed [DATA_W-1:0] q_row_data [0:D_MODEL-1];
    logic q_row_valid;
    logic row_load_ready;
    logic row_clear;

    logic signed [DATA_W-1:0] k_tile_data [0:BK-1][0:D_MODEL-1];
    logic signed [DATA_W-1:0] v_tile_data [0:BK-1][0:D_MODEL-1];
    logic tile_valid;
    logic tile_load_ready;
    logic tile_clear;

    logic signed [DATA_W-1:0] k_dot_data [0:D_MODEL-1];
    logic signed [DATA_W-1:0] q_work_data [0:D_MODEL-1];
    logic signed [DATA_W-1:0] k_work_data [0:D_MODEL-1];
    logic dot_start;
    logic dot_busy;
    logic dot_done;
    logic signed [ACC_W-1:0] dot_value;
    logic signed [ACC_W-1:0] last_dot_q;

    logic signed [DATA_W-1:0] o_data_q [0:D_MODEL-1];
    int comb_d;
    int seq_d;
    genvar o_gen;

    generate
        for (o_gen = 0; o_gen < D_MODEL; o_gen = o_gen + 1) begin : gen_o_data_assign
            assign o_data[o_gen] = o_data_q[o_gen];
        end
    endgenerate

    tile_scheduler #(
        .S_LEN(S_LEN),
        .BK(BK)
    ) u_scheduler (
        .clk(clk),
        .rst_n(rst_n),
        .start(sched_start),
        .step(sched_step),
        .valid(sched_valid),
        .done(sched_done),
        .row_index(sched_row),
        .kv_start(sched_kv_start),
        .kv_len(sched_kv_len),
        .first_tile(),
        .last_tile(sched_last_tile),
        .last_row(sched_last_row)
    );

    row_buffer #(
        .D_MODEL(D_MODEL),
        .DATA_W(DATA_W)
    ) u_q_row_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .clear(row_clear),
        .load_valid(q_data_valid && q_data_ready),
        .load_ready(row_load_ready),
        .load_data(q_data),
        .valid(q_row_valid),
        .row_data(q_row_data)
    );

    tile_buffer #(
        .BK(BK),
        .D_MODEL(D_MODEL),
        .DATA_W(DATA_W)
    ) u_kv_tile_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .clear(tile_clear),
        .load_valid(kv_data_valid && kv_data_ready),
        .load_ready(tile_load_ready),
        .k_load(k_tile),
        .v_load(v_tile),
        .valid(tile_valid),
        .k_data(k_tile_data),
        .v_data(v_tile_data)
    );

    dot_product_engine #(
        .D_MODEL(D_MODEL),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) u_dot_product (
        .clk(clk),
        .rst_n(rst_n),
        .start(dot_start),
        .q_vec(q_work_data),
        .k_vec(k_work_data),
        .busy(dot_busy),
        .done(dot_done),
        .dot(dot_value)
    );

    function automatic logic signed [DATA_W-1:0] saturate_to_data(
        input logic signed [ACC_W-1:0] value
    );
        logic signed [ACC_W-1:0] max_value;
        logic signed [ACC_W-1:0] min_value;
        begin
            max_value = (1 <<< (DATA_W - 1)) - 1;
            min_value = -(1 <<< (DATA_W - 1));

            if (value > max_value) begin
                saturate_to_data = max_value[DATA_W-1:0];
            end else if (value < min_value) begin
                saturate_to_data = min_value[DATA_W-1:0];
            end else begin
                saturate_to_data = value[DATA_W-1:0];
            end
        end
    endfunction

    always_comb begin
        busy          = (state_q != ST_IDLE) && (state_q != ST_DONE);
        done          = (state_q == ST_DONE);
        error         = 1'b0;

        q_req_valid   = (state_q == ST_REQ_Q) && sched_valid;
        q_req_row     = sched_row;
        q_data_ready  = (state_q == ST_WAIT_Q) && row_load_ready;

        kv_req_valid  = (state_q == ST_REQ_KV) && sched_valid;
        kv_req_start  = sched_kv_start;
        kv_req_len    = sched_kv_len;
        kv_data_ready = (state_q == ST_WAIT_KV) && tile_load_ready;

        o_valid       = (state_q == ST_EMIT_O);
        o_row         = sched_row;

        sched_start   = start && (state_q == ST_IDLE);
        sched_step    = 1'b0;
        dot_start     = (state_q == ST_DOT_START);
        row_clear     = sched_start;
        tile_clear    = sched_start;

        for (comb_d = 0; comb_d < D_MODEL; comb_d = comb_d + 1) begin
            k_dot_data[comb_d] = k_work_data[comb_d];
        end

        if (state_q == ST_STEP) begin
            sched_step = 1'b1;
            tile_clear = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q    <= ST_IDLE;
            last_dot_q <= '0;
            for (seq_d = 0; seq_d < D_MODEL; seq_d = seq_d + 1) begin
                o_data_q[seq_d] <= '0;
                q_work_data[seq_d] <= '0;
                k_work_data[seq_d] <= '0;
            end
        end else begin
            case (state_q)
                ST_IDLE: begin
                    if (start) begin
                        state_q <= ST_REQ_Q;
                    end
                end

                ST_REQ_Q: begin
                    if (sched_valid && q_req_ready) begin
                        state_q <= ST_WAIT_Q;
                    end
                end

                ST_WAIT_Q: begin
                    if (q_data_valid && q_data_ready) begin
                        for (seq_d = 0; seq_d < D_MODEL; seq_d = seq_d + 1) begin
                            q_work_data[seq_d] <= q_data[seq_d];
                        end
                        state_q <= ST_REQ_KV;
                    end
                end

                ST_REQ_KV: begin
                    if (sched_valid && kv_req_ready) begin
                        state_q <= ST_WAIT_KV;
                    end
                end

                ST_WAIT_KV: begin
                    if (kv_data_valid && kv_data_ready) begin
                        for (seq_d = 0; seq_d < D_MODEL; seq_d = seq_d + 1) begin
                            k_work_data[seq_d] <= k_tile[0][seq_d];
                        end
                        state_q <= ST_DOT_START;
                    end
                end

                ST_DOT_START: begin
                    state_q <= ST_DOT_WAIT;
                end

                ST_DOT_WAIT: begin
                    if (dot_done) begin
                        last_dot_q <= dot_value;

                        if (sched_last_tile) begin
                            for (seq_d = 0; seq_d < D_MODEL; seq_d = seq_d + 1) begin
                                o_data_q[seq_d] <= '0;
                            end
                            o_data_q[0] <= saturate_to_data(dot_value >>> FRAC_W);
                            state_q <= ST_EMIT_O;
                        end else begin
                            state_q <= ST_STEP;
                        end
                    end
                end

                ST_EMIT_O: begin
                    if (o_ready) begin
                        if (sched_last_row && sched_last_tile) begin
                            state_q <= ST_DONE;
                        end else begin
                            state_q <= ST_STEP;
                        end
                    end
                end

                ST_STEP: begin
                    if (sched_last_tile) begin
                        state_q <= ST_REQ_Q;
                    end else begin
                        state_q <= ST_REQ_KV;
                    end
                end

                ST_DONE: begin
                    state_q <= ST_IDLE;
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

    // Keep config inputs referenced in the MVP until softmax/mask blocks land.
    logic unused_config;
    assign unused_config = causal_en ^ neg_large[0] ^ scale[0] ^ last_dot_q[0] ^ sched_done;
endmodule
