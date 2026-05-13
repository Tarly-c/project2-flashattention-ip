`timescale 1ns/1ps

module tb_dot_product_engine;
    localparam int D_MODEL = 4;
    localparam int DATA_W  = 16;
    localparam int ACC_W   = 48;

    logic clk;
    logic rst_n;
    logic start;
    logic signed [DATA_W-1:0] q_vec [0:D_MODEL-1];
    logic signed [DATA_W-1:0] k_vec [0:D_MODEL-1];
    logic busy;
    logic done;
    logic signed [ACC_W-1:0] dot;

    dot_product_engine #(
        .D_MODEL(D_MODEL),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .q_vec(q_vec),
        .k_vec(k_vec),
        .busy(busy),
        .done(done),
        .dot(dot)
    );

    always #5 clk = ~clk;

    task automatic run_case(
        input logic signed [DATA_W-1:0] q0,
        input logic signed [DATA_W-1:0] q1,
        input logic signed [DATA_W-1:0] q2,
        input logic signed [DATA_W-1:0] q3,
        input logic signed [DATA_W-1:0] k0,
        input logic signed [DATA_W-1:0] k1,
        input logic signed [DATA_W-1:0] k2,
        input logic signed [DATA_W-1:0] k3,
        input logic signed [ACC_W-1:0] expected
    );
        begin
            q_vec[0] = q0;
            q_vec[1] = q1;
            q_vec[2] = q2;
            q_vec[3] = q3;
            k_vec[0] = k0;
            k_vec[1] = k1;
            k_vec[2] = k2;
            k_vec[3] = k3;

            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            wait (done);
            @(posedge clk);

            if (dot !== expected) begin
                $display("FAIL dot=%0d expected=%0d dot_hex=%012h expected_hex=%012h",
                         dot, expected, dot, expected);
                $fatal(1);
            end
            $display("PASS dot=%0d hex=%012h", dot, dot);
        end
    endtask

    initial begin
        $dumpfile("tb_dot_product_engine.vcd");
        $dumpvars(0, tb_dot_product_engine);

        clk   = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        run_case(16'sd1, 16'sd2, 16'sd3, 16'sd4,
                 16'sd2, 16'sd3, 16'sd4, 16'sd5,
                 48'sd40);

        run_case(-16'sd1, 16'sd2, -16'sd3, 16'sd4,
                 16'sd5, -16'sd6, 16'sd7, -16'sd8,
                 -48'sd70);

        $display("tb_dot_product_engine PASS");
        $finish;
    end
endmodule
