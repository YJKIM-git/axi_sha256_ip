`timescale 1ns / 1ps

module sha256_sig0 (
    input  logic [31:0] in_i,
    output logic [31:0] out_o
);
  logic [31:0] r7;
  logic [31:0] r18;

  sha256_rotr #(
      .SHIFT(7)
  ) u_rotr7 (
      .in_i (in_i),
      .out_o(r7)
  );
  sha256_rotr #(
      .SHIFT(18)
  ) u_rotr18 (
      .in_i (in_i),
      .out_o(r18)
  );

  assign out_o = r7 ^ r18 ^ (in_i >> 3);
endmodule
