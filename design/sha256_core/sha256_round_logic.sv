`timescale 1ns / 1ps

module sha256_round_logic (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic [31:0] c_i,
    input  logic [31:0] d_i,
    input  logic [31:0] e_i,
    input  logic [31:0] f_i,
    input  logic [31:0] g_i,
    input  logic [31:0] h_i,
    input  logic [31:0] wk_i,
    output logic [31:0] next_a_o,
    output logic [31:0] next_b_o,
    output logic [31:0] next_c_o,
    output logic [31:0] next_d_o,
    output logic [31:0] next_e_o,
    output logic [31:0] next_f_o,
    output logic [31:0] next_g_o,
    output logic [31:0] next_h_o
);
  logic [31:0] ep0_w;
  logic [31:0] ep1_w;
  logic [31:0] ch_w;
  logic [31:0] maj_w;
  logic [31:0] sum1;
  logic [31:0] sum2;
  logic [31:0] t1_o;
  logic [31:0] t2_o;
  logic [31:0] next_a_w;
  logic [31:0] next_e_w;

  sha256_ep0 u_ep0_mod (
      .in_i (a_i),
      .out_o(ep0_w)
  );
  sha256_ep1 u_ep1_mod (
      .in_i (e_i),
      .out_o(ep1_w)
  );
  sha256_ch u_ch_mod (
      .x_i  (e_i),
      .y_i  (f_i),
      .z_i  (g_i),
      .out_o(ch_w)
  );
  sha256_maj u_maj_mod (
      .x_i  (a_i),
      .y_i  (b_i),
      .z_i  (c_i),
      .out_o(maj_w)
  );

  sha256_add32 u_add1 (
      .a_i  (h_i),
      .b_i  (ep1_w),
      .sum_o(sum1)
  );
  sha256_add32 u_add2 (
      .a_i  (sum1),
      .b_i  (ch_w),
      .sum_o(sum2)
  );
  sha256_add32 u_add3 (
      .a_i  (sum2),
      .b_i  (wk_i),
      .sum_o(t1_o)
  );
  sha256_add32 u_add4 (
      .a_i  (ep0_w),
      .b_i  (maj_w),
      .sum_o(t2_o)
  );
  sha256_add32 u_add5 (
      .a_i  (t1_o),
      .b_i  (t2_o),
      .sum_o(next_a_w)
  );
  sha256_add32 u_add6 (
      .a_i  (d_i),
      .b_i  (t1_o),
      .sum_o(next_e_w)
  );

  assign next_a_o = next_a_w;
  assign next_b_o = a_i;
  assign next_c_o = b_i;
  assign next_d_o = c_i;
  assign next_e_o = next_e_w;
  assign next_f_o = e_i;
  assign next_g_o = f_i;
  assign next_h_o = g_i;
endmodule
