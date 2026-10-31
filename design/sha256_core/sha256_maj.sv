`timescale 1ns / 1ps

module sha256_maj (
    input  logic [31:0] x_i,
    input  logic [31:0] y_i,
    input  logic [31:0] z_i,
    output logic [31:0] out_o
);
  assign out_o = (x_i & y_i) ^ (x_i & z_i) ^ (y_i & z_i);
endmodule
