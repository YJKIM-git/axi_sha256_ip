`timescale 1ns / 1ps

module sha256_message_schedule (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         load_block_i,
    input  logic [511:0] block_i,
    input  logic         update_i,
    input  logic [  5:0] round_idx_i,
    output logic [ 31:0] w_o
);
  reg [31:0] w_mem[0:15];
  integer i;

  logic [3:0] slot_i;
  logic [3:0] slot_m2;
  logic [3:0] slot_m7;
  logic [3:0] slot_m15;
  logic [31:0] w_m2;
  logic [31:0] w_m7;
  logic [31:0] w_m15;
  logic [31:0] sig0_w;
  logic [31:0] sig1_w;
  logic [31:0] schedule_w;

  assign slot_i = round_idx_i[3:0];
  assign slot_m2 = round_idx_i[3:0] - 4'd2;
  assign slot_m7 = round_idx_i[3:0] - 4'd7;
  assign slot_m15 = round_idx_i[3:0] - 4'd15;

  assign w_m2 = w_mem[slot_m2];
  assign w_m7 = w_mem[slot_m7];
  assign w_m15 = w_mem[slot_m15];

  sha256_sig0 u_sig0 (
      .in_i (w_m15),
      .out_o(sig0_w)
  );
  sha256_sig1 u_sig1 (
      .in_i (w_m2),
      .out_o(sig1_w)
  );

  assign schedule_w = sig1_w + w_m7 + sig0_w + w_mem[slot_i];
  assign w_o = (round_idx_i < 6'd16) ? w_mem[slot_i] : schedule_w;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1) begin
        w_mem[i] <= 32'h00000000;
      end
    end else if (load_block_i) begin
      for (i = 0; i < 16; i = i + 1) begin
        w_mem[i] <= block_i[511-(i*32)-:32];
      end
    end else if (update_i) begin
      w_mem[slot_i] <= w_o;
    end
  end
endmodule
