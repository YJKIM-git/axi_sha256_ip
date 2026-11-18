`timescale 1ns / 1ps

module sha256_controller (
    input  logic       clk_i,
    input  logic       rst_n_i,
    input  logic       start_i,
    output logic       load_block_o,
    output logic       init_o,
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
    STATE_ROUND,
    STATE_UPDATE,
    STATE_DONE
  } state_t;

  state_t state, nstate;
  logic [5:0] round_idx_r;

  always_ff @(posedge clk_i or negedge rst_n_i) begin : STATE_REG
    if (!rst_n_i) begin
      state      <= STATE_IDLE;
      round_idx_r <= 6'd0;
    end else begin
      state      <= nstate;
      round_idx_r <= (state == STATE_ROUND) ? round_idx_r + 6'd1 : 6'd0;
    end
  end

  always_comb begin : NEXT_STATE_LOGIC
    nstate = state;
    unique case (state)
      STATE_IDLE: begin
        nstate = start_i ? STATE_INIT : STATE_IDLE;
      end

      STATE_INIT: begin
        nstate = STATE_ROUND;
      end

      STATE_ROUND: begin
        nstate = (round_idx_r == 6'd63) ? STATE_UPDATE : STATE_ROUND;
      end

      STATE_UPDATE: begin
        nstate = STATE_DONE;
      end

      STATE_DONE: begin
        nstate = STATE_IDLE;
      end

      default: begin
        nstate = STATE_IDLE;
      end
    endcase
  end

  always_comb begin : OUTPUT_LOGIC
    load_block_o = 1'b0;
    init_o       = 1'b0;
    round_en_o   = 1'b0;
    update_o     = 1'b0;
    ready_o      = 1'b0;
    busy_o       = 1'b1;
    done_o       = 1'b0;
    round_idx_o  = round_idx_r;

    unique case (state)
      STATE_IDLE: begin
        ready_o = 1'b1;
        busy_o  = 1'b0;
      end

      STATE_INIT: begin
        load_block_o = 1'b1;
        init_o       = 1'b1;
      end

      STATE_ROUND: begin
        round_en_o = 1'b1;
      end

      STATE_UPDATE: begin
        update_o = 1'b1;
      end

      STATE_DONE: begin
        done_o  = 1'b1;
        ready_o = 1'b1;
        busy_o  = 1'b0;
      end

      default: begin
        ready_o = 1'b1;
        busy_o  = 1'b0;
      end
    endcase
  end

endmodule
