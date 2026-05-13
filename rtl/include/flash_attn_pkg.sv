`timescale 1ns/1ps

package flash_attn_pkg;
    parameter int S_LEN      = 256;
    parameter int D_MODEL    = 64;
    parameter int BK         = 16;

    parameter int DATA_W     = 16;
    parameter int FRAC_W     = 8;
    parameter int DOT_W      = 48;
    parameter int ACC_W      = 48;
    parameter int SOFTMAX_W  = 32;

    parameter int ADDR_W     = 64;
    parameter int AXI_DATA_W = 64;
    parameter int AXI_STRB_W = AXI_DATA_W / 8;

    parameter logic signed [31:0] DEFAULT_NEG_LARGE = -32'sd32768;
    parameter logic signed [31:0] DEFAULT_SCALE     = 32'sd32; // 0.125 in Q8.8
endpackage
