// -----------------------------------------------------------------------------
// Module Name   : sha256_core
// Author        : Youngjin Kim
// Description   : SHA-256 Core module that implements the SHA-256 hashing algorithm.
// Reference     : Micro_Architecture_Specification.md
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module sha256_core (
    input  logic         clk_i,
    input  logic         rst_n_i,
    input  logic         start_i,
    input  logic [255:0] state_in_i,
    input  logic [511:0] block_i,
    output logic         ready_o,
    output logic         busy_o,
    output logic         done_o,
    output logic [255:0] state_out_o
);
  logic       load_block_o;
  logic       init_o;
  logic       pre_round_o;
  logic       round_en_o;
  logic       update_o;
  logic [5:0] round_idx_o;

  sha256_controller u_controller (
      .clk_i       (clk_i),
      .rst_n_i     (rst_n_i),
      .start_i     (start_i),
      .load_block_o(load_block_o),
      .init_o      (init_o),
      .pre_round_o (pre_round_o),
      .round_en_o  (round_en_o),
      .update_o    (update_o),
      .ready_o     (ready_o),
      .busy_o      (busy_o),
      .done_o      (done_o),
      .round_idx_o (round_idx_o)
  );

  sha256_datapath u_datapath (
      .clk_i       (clk_i),
      .rst_n_i     (rst_n_i),
      .load_block_i(load_block_o),
      .init_i      (init_o),
      .pre_round_i (pre_round_o),
      .round_en_i  (round_en_o),
      .update_i    (update_o),
      .round_idx_i (round_idx_o),
      .state_in_i  (state_in_i),
      .block_in_i  (block_i),
      .state_out_o (state_out_o)
  );
endmodule
