`timescale 1ns / 1ps

module sha256_datapath (
    input  logic         clk_i,
    input  logic         rst_n_i,
    input  logic         load_block_i,
    input  logic         init_i,
    input  logic         pre_round_i,
    input  logic         round_en_i,
    input  logic         update_i,
    input  logic [  5:0] round_idx_i,
    input  logic [255:0] state_in_i,
    input  logic [511:0] block_in_i,
    output logic [255:0] state_out_o
);
  logic [31:0] a_r;
  logic [31:0] b_r;
  logic [31:0] c_r;
  logic [31:0] d_r;
  logic [31:0] e_r;
  logic [31:0] f_r;
  logic [31:0] g_r;
  logic [31:0] h_r;

  logic [31:0] w_o;
  logic [31:0] k_o;
  logic [31:0] wk_r;
  logic [31:0] wk_sum;
  logic [31:0] next_a_o;
  logic [31:0] next_b_o;
  logic [31:0] next_c_o;
  logic [31:0] next_d_o;
  logic [31:0] next_e_o;
  logic [31:0] next_f_o;
  logic [31:0] next_g_o;
  logic [31:0] next_h_o;

  sha256_message_schedule u_message_schedule (
      .clk         (clk_i),
      .rst_n       (rst_n_i),
      .load_block_i(load_block_i),
      .block_i     (block_in_i),
      .update_i    (round_en_i),
      .round_idx_i (round_idx_i),
      .w_o         (w_o)
  );

  sha256_k_rom u_k_rom (
      .addr_i(round_idx_i),
      .k_o   (k_o)
  );

  assign wk_sum = w_o + k_o;

  sha256_round_logic u_round_logic (
      .a_i     (a_r),
      .b_i     (b_r),
      .c_i     (c_r),
      .d_i     (d_r),
      .e_i     (e_r),
      .f_i     (f_r),
      .g_i     (g_r),
      .h_i     (h_r),
      .wk_i    (wk_r),
      .next_a_o(next_a_o),
      .next_b_o(next_b_o),
      .next_c_o(next_c_o),
      .next_d_o(next_d_o),
      .next_e_o(next_e_o),
      .next_f_o(next_f_o),
      .next_g_o(next_g_o),
      .next_h_o(next_h_o)
  );

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      a_r <= 32'd0;
      b_r <= 32'd0;
      c_r <= 32'd0;
      d_r <= 32'd0;
      e_r <= 32'd0;
      f_r <= 32'd0;
      g_r <= 32'd0;
      h_r <= 32'd0;
      wk_r <= 32'd0;
      state_out_o <= {
        32'h6a09e667,
        32'hbb67ae85,
        32'h3c6ef372,
        32'ha54ff53a,
        32'h510e527f,
        32'h9b05688c,
        32'h1f83d9ab,
        32'h5be0cd19
      };
    end else begin
      if (load_block_i) begin
      end

      if (init_i) begin
        a_r <= state_in_i[255:224];
        b_r <= state_in_i[223:192];
        c_r <= state_in_i[191:160];
        d_r <= state_in_i[159:128];
        e_r <= state_in_i[127:96];
        f_r <= state_in_i[95:64];
        g_r <= state_in_i[63:32];
        h_r <= state_in_i[31:0];
      end

      if (pre_round_i || round_en_i) begin
        wk_r <= wk_sum;
      end

      if (round_en_i) begin
        a_r <= next_a_o;
        b_r <= next_b_o;
        c_r <= next_c_o;
        d_r <= next_d_o;
        e_r <= next_e_o;
        f_r <= next_f_o;
        g_r <= next_g_o;
        h_r <= next_h_o;
      end

      if (update_i) begin
        state_out_o <= {
          state_in_i[255:224] + a_r,
          state_in_i[223:192] + b_r,
          state_in_i[191:160] + c_r,
          state_in_i[159:128] + d_r,
          state_in_i[127:96] + e_r,
          state_in_i[95:64] + f_r,
          state_in_i[63:32] + g_r,
          state_in_i[31:0] + h_r
        };
      end
    end
  end
endmodule
