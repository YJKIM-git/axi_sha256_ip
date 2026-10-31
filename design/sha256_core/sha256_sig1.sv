`timescale 1ns / 1ps

module sha256_sig1 (
    input  logic [31:0] in_i,
    output logic [31:0] out_o
);
  logic [31:0] r17;
  logic [31:0] r19;

  sha256_rotr #(
      .SHIFT(17)
  ) u_rotr17 (
      .in_i (in_i),
      .out_o(r17)
  );
  sha256_rotr #(
      .SHIFT(19)
  ) u_rotr19 (
      .in_i (in_i),
      .out_o(r19)
  );

  assign out_o = r17 ^ r19 ^ (in_i >> 10);
endmodule
