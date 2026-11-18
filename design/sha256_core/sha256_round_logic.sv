`timescale 1ns / 1ps

module sha256_round_logic
  import sha256_pkg::*;
(
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic [31:0] c_i,
    input  logic [31:0] d_i,
    input  logic [31:0] e_i,
    input  logic [31:0] f_i,
    input  logic [31:0] g_i,
    input  logic [31:0] h_i,
    input  logic [31:0] w_i,
    input  logic [31:0] k_i,
    output logic [31:0] next_a_o,
    output logic [31:0] next_b_o,
    output logic [31:0] next_c_o,
    output logic [31:0] next_d_o,
    output logic [31:0] next_e_o,
    output logic [31:0] next_f_o,
    output logic [31:0] next_g_o,
    output logic [31:0] next_h_o
);
  //for FPGA optimization (* keep = "true" *), ignore in ASIC synthesis
  // optimized on Zybo Z7-20
  (* keep = "true" *) logic [31:0] wh_sum, sum1, sum2, t1_o, t2_o, t2_k_w;
  //logic [31:0] wh_sum, sum1, sum2, t1_o, t2_o, t2_k_w;

  assign wh_sum = w_i + h_i;
  assign sum2 = ep1(e_i) + ch(e_i, f_i, g_i);
  assign t2_o = ep0(a_i) + maj(a_i, b_i, c_i);
  assign t1_o = wh_sum + sum2;
  assign sum1 = d_i + k_i;
  assign t2_k_w = t2_o + k_i;

  assign next_a_o = t1_o + t2_k_w;
  assign next_b_o = a_i;
  assign next_c_o = b_i;
  assign next_d_o = c_i;
  assign next_e_o = t1_o + sum1;
  assign next_f_o = e_i;
  assign next_g_o = f_i;
  assign next_h_o = g_i;
endmodule
