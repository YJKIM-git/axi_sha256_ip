`timescale 1ns / 1ps

module sha256_ep0 (
    input  logic [31:0] in_i,
    output logic [31:0] out_o
);
  logic [31:0] r2;
  logic [31:0] r13;
  logic [31:0] r22;

  sha256_rotr #(
      .SHIFT(2)
  ) u_rotr2 (
      .in_i (in_i),
      .out_o(r2)
  );
  sha256_rotr #(
      .SHIFT(13)
  ) u_rotr13 (
      .in_i (in_i),
      .out_o(r13)
  );
  sha256_rotr #(
      .SHIFT(22)
  ) u_rotr22 (
      .in_i (in_i),
      .out_o(r22)
  );

  assign out_o = r2 ^ r13 ^ r22;
endmodule
