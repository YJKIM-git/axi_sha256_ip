`timescale 1ns / 1ps

module sha256_ep1 (
    input  logic [31:0] in_i,
    output logic [31:0] out_o
);
  logic [31:0] r6;
  logic [31:0] r11;
  logic [31:0] r25;

  sha256_rotr #(
      .SHIFT(6)
  ) u_rotr6 (
      .in_i (in_i),
      .out_o(r6)
  );
  sha256_rotr #(
      .SHIFT(11)
  ) u_rotr11 (
      .in_i (in_i),
      .out_o(r11)
  );
  sha256_rotr #(
      .SHIFT(25)
  ) u_rotr25 (
      .in_i (in_i),
      .out_o(r25)
  );

  assign out_o = r6 ^ r11 ^ r25;
endmodule
