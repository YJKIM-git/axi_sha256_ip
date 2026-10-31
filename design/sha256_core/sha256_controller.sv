`timescale 1ns / 1ps

module sha256_controller (
    input  logic       clk_i,
    input  logic       rst_n_i,
    input  logic       start_i,
    output logic       load_block_o,
    output logic       init_o,
    output logic       pre_round_o,
    output logic       round_en_o,
    output logic       update_o,
    output logic       ready_o,
    output logic       busy_o,
    output logic       done_o,
    output logic [5:0] round_idx_o
);
  typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_INIT,
    STATE_PRE_ROUND,
    STATE_ROUND,
    STATE_UPDATE,
    STATE_DONE
  } state_t;

  state_t       state_r;
  logic   [5:0] round_idx_r;
  logic         repeat_last_round_r;

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      state_r             <= STATE_IDLE;
      round_idx_r         <= 6'd0;
      repeat_last_round_r <= 1'b0;
      load_block_o        <= 1'b0;
      init_o              <= 1'b0;
      pre_round_o         <= 1'b0;
      round_en_o          <= 1'b0;
      update_o            <= 1'b0;
      ready_o             <= 1'b1;
      busy_o              <= 1'b0;
      done_o              <= 1'b0;
      round_idx_o         <= 6'd0;
    end else begin
      load_block_o <= 1'b0;
      init_o       <= 1'b0;
      pre_round_o  <= 1'b0;
      round_en_o   <= 1'b0;
      update_o     <= 1'b0;
      done_o       <= 1'b0;

      case (state_r)
        STATE_IDLE: begin
          ready_o <= 1'b1;
          busy_o  <= 1'b0;
          if (start_i) begin
            state_r <= STATE_INIT;
            ready_o <= 1'b0;
            busy_o  <= 1'b1;
          end
        end

        STATE_INIT: begin
          load_block_o        <= 1'b1;
          init_o              <= 1'b1;
          round_idx_o         <= 6'd0;
          round_idx_r         <= 6'd1;
          repeat_last_round_r <= 1'b0;
          state_r             <= STATE_PRE_ROUND;
        end

        STATE_PRE_ROUND: begin
          pre_round_o <= 1'b1;
          round_idx_o <= 6'd0;
          state_r     <= STATE_ROUND;
        end

        STATE_ROUND: begin
          round_en_o  <= 1'b1;
          round_idx_o <= round_idx_r;
          if (round_idx_r == 6'd63) begin
            if (repeat_last_round_r) begin
              repeat_last_round_r <= 1'b0;
              state_r             <= STATE_UPDATE;
            end else begin
              repeat_last_round_r <= 1'b1;
              round_idx_r         <= 6'd63;
            end
          end else begin
            round_idx_r <= round_idx_r + 6'd1;
            repeat_last_round_r <= 1'b0;
          end
        end

        STATE_UPDATE: begin
          round_idx_o <= round_idx_r;
          update_o    <= 1'b1;
          state_r     <= STATE_DONE;
        end

        STATE_DONE: begin
          done_o              <= 1'b1;
          ready_o             <= 1'b1;
          busy_o              <= 1'b0;
          round_idx_o         <= 6'd0;
          round_idx_r         <= 6'd0;
          repeat_last_round_r <= 1'b0;
          state_r             <= STATE_IDLE;
        end

        default: begin
          state_r <= STATE_IDLE;
          ready_o <= 1'b1;
          busy_o  <= 1'b0;
        end
      endcase
    end
  end
endmodule
