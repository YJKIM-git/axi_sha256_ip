`timescale 1ns / 1ps

module sha256_rotr #(
    parameter integer SHIFT = 1
) (
    input  logic [31:0] in_i,
    output logic [31:0] out_o
);
  assign out_o = (in_i >> SHIFT) | (in_i << (32 - SHIFT));
endmodule
