`timescale 1ns / 1ps

module sha256_message_schedule
  import sha256_pkg::*;
(
    input  logic         clk_i,
    input  logic         rst_n_i,
    input  logic         load_block_i,
    input  logic [511:0] block_i,
    input  logic         update_i,
    output logic [ 31:0] w_o
);
  logic [31:0] w_mem[0:15];
  logic [31:0] schedule_w;

  assign schedule_w = (sig1(w_mem[14]) + sig0(w_mem[1])) + (w_mem[9] + w_mem[0]);
  assign w_o        = w_mem[0];

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      for (int i = 0; i < 16; i = i + 1) begin
        w_mem[i] <= 32'h00000000;
      end
    end else begin
      unique case ({
        load_block_i, update_i
      })
        2'b10: begin
          for (int i = 0; i < 16; i = i + 1) begin
            w_mem[i] <= block_i[511-(i*32)-:32];
          end
        end
        2'b01: begin
          for (int i = 0; i < 15; i = i + 1) begin
            w_mem[i] <= w_mem[i+1];
          end
          w_mem[15] <= schedule_w;
        end
        default: ;
      endcase
    end
  end
endmodule
