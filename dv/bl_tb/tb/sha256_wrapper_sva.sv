//------------------------------------------------------------
//   Copyright 2010-2018 Mentor Graphics Corporation
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------
//   Copyright 2026 Youngjin Kim
//
//   Modifications:
//   - Adopted the UVM architectural framework from the original APB VIP.
//   - Defines white-box assertions for SHA-256 wrapper protocol and control behavior.
//------------------------------------------------------------------------------

module sha256_wrapper_sva (
    input logic        clk_i,
    input logic        rst_n_i,
    input logic [ 2:0] state,
    input logic [ 2:0] ret_state,
    input logic        ctrl_start_pulse,
    input logic        ctrl_en,
    input logic        ctrl_irq_en,
    input logic        ctrl_soft_reset,
    input logic        status_busy,
    input logic        status_done,
    input logic        irq_o,
    input logic        s_axi_bvalid,
    input logic        s_axi_bready,
    input logic [ 1:0] s_axi_bresp,
    input logic [63:0] msg_len,
    input logic [ 6:0] byte_cnt,
    input logic        first_block,
    input logic [ 7:0] block_b           [0:63],
    input logic        transaction_active,
    input logic [31:0] state_in_reg      [ 0:7],

    input logic        status_err_flag,
    input logic        slv_reg_wen,
    input logic [ 7:0] awaddr_reg,
    input logic [ 2:0] awprot_reg,
    input logic [31:0] wdata_reg,
    input logic [ 3:0] wstrb_reg,
    input logic        slv_reg_ren,
    input logic [ 7:0] araddr_reg,
    input logic [ 2:0] arprot_reg,
    input logic        s_axi_rvalid,
    input logic [ 1:0] s_axi_rresp,
    input logic [31:0] s_axi_rdata,
    input logic        core_done,
    input logic        s_axis_tlast,
    input logic        clear_done_pulse,

    input logic         s_axis_tvalid,
    input logic         s_axis_tready,
    input logic         axis_tkeep_invalid,
    input logic         axis_tkeep_err,
    input logic [  2:0] valid_bytes,
    input logic         block_pending,
    input logic [511:0] core_block_reg,
    input logic         core_start,
    input logic         core_busy,
    input logic [255:0] core_state_out,
    input logic [ 31:0] core_state_out_reg[0:7]
);

  localparam [2:0] S_IDLE = 3'd0;
  localparam [2:0] S_RCV = 3'd1;
  localparam [2:0] S_PAD_80 = 3'd2;
  localparam [2:0] S_PAD_LEN = 3'd3;
  localparam [2:0] S_START_CORE = 3'd4;
  localparam [2:0] S_WAIT_CORE = 3'd5;
  localparam [2:0] S_DONE = 3'd6;

  logic next_blk_ready;
  assign next_blk_ready = (state == S_RCV && s_axis_tvalid && s_axis_tready && !axis_tkeep_invalid && (byte_cnt + valid_bytes == 7'd64)) ||
                          (state == S_PAD_80 && (byte_cnt + 7'd1 > 7'd56)) ||
                          (state == S_PAD_LEN);

  // =========================================================
  // SVA: test_plan_csr/csr_pulse_clear, csr_decouple_sync
  // =========================================================
  property p_start_pulse_clear;
    @(posedge clk_i) disable iff (!rst_n_i) ctrl_start_pulse |=> !ctrl_start_pulse;
  endproperty
  a_start_pulse_clear :
  assert property (p_start_pulse_clear);

  property p_soft_reset_clear;
    @(posedge clk_i) disable iff (!rst_n_i) ctrl_soft_reset |=> !ctrl_soft_reset;
  endproperty
  a_soft_reset_clear :
  assert property (p_soft_reset_clear);

  property p_clear_done_pulse;
    @(posedge clk_i) disable iff (!rst_n_i) clear_done_pulse |=> !clear_done_pulse;
  endproperty
  a_clear_done_pulse :
  assert property (p_clear_done_pulse);

  property p_sync_err_no_irq;
    @(posedge clk_i) disable iff (!rst_n_i)
      (s_axi_bvalid && s_axi_bready && (s_axi_bresp == 2'b10)
      && !axis_tkeep_err && ctrl_irq_en
      && !status_done && !status_err_flag)
      |=> (!status_err_flag && !irq_o);
  endproperty
  a_sync_err_no_irq :
  assert property (p_sync_err_no_irq);

  property p_ctrl_read_zero_w1p;
    @(posedge clk_i) disable iff (!rst_n_i)
      (slv_reg_ren && (araddr_reg[7:2] == 6'h01)) |=> (s_axi_rdata[31:2] == 30'd0);
  endproperty
  a_ctrl_read_zero_w1p :
  assert property (p_ctrl_read_zero_w1p);

  property p_start_ignored_when_disabled;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset)
      (state == S_IDLE && ctrl_start_pulse && !ctrl_en) |=> (state == S_IDLE && !transaction_active);
  endproperty
  a_start_ignored_when_disabled :
  assert property (p_start_ignored_when_disabled);
  // =========================================================
  // SVA: test_plan_overall/oa_zeroization, oa_latency, oa_recovery
  // =========================================================
  function automatic bit is_block_b_zero(input logic [7:0] buf_b[0:63]);
    for (int i = 0; i < 64; i++) begin
      if (buf_b[i] !== 8'h00) return 1'b0;
    end
    return 1'b1;
  endfunction

  property p_oa_zeroization;
    @(posedge clk_i) disable iff (!rst_n_i) ((state == S_IDLE) || $past(
        state == S_START_CORE && !ctrl_soft_reset
    )) |-> is_block_b_zero(block_b);
  endproperty
  a_oa_zeroization :
  assert property (p_oa_zeroization);

  property p_oa_latency;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset) $rose(
        state == S_START_CORE && ret_state == S_DONE
    ) |=> ##68 status_done;
  endproperty
  a_oa_latency :
  assert property (p_oa_latency);

  property p_oa_recovery;
    @(posedge clk_i) disable iff (!rst_n_i)
      ctrl_soft_reset
      |=> (state == S_IDLE && ret_state == S_IDLE && !block_pending &&
           !status_busy && !status_done && !status_err_flag && first_block &&
           byte_cnt == 7'd0 && msg_len == 64'd0 && core_block_reg == 512'd0 &&
           core_state_out_reg[0] == 32'd0 && core_state_out_reg[7] == 32'd0 &&
           state_in_reg[0] == 32'h6a09e667 && state_in_reg[7] == 32'h5be0cd19);
  endproperty
  a_oa_recovery :
  assert property (p_oa_recovery);

  // =========================================================
  // SVA: test_plan_overall/oa_lifecycle
  // =========================================================
  property p_lifecycle_irq_behavior;
    @(posedge clk_i) disable iff (!rst_n_i)
      irq_o == ((status_done || status_err_flag) && ctrl_irq_en);
  endproperty
  a_lifecycle_irq_behavior :
  assert property (p_lifecycle_irq_behavior);

  property p_lifecycle_irq_clear;
    @(posedge clk_i) disable iff (!rst_n_i) clear_done_pulse |=> (!status_done && !irq_o);
  endproperty
  a_lifecycle_irq_clear :
  assert property (p_lifecycle_irq_clear);

  // =========================================================
  // SVA: test_plan_overall/oa_overlap_rcv
  // =========================================================
  property p_oa_overlap_rcv_ready;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset)
    (state == S_START_CORE && ret_state != S_DONE)
    |-> core_start ##1 (state == $past(
        ret_state
    ) && ((state == S_RCV && ctrl_en) ? s_axis_tready : 1'b1));
  endproperty
  a_oa_overlap_rcv_ready :
  assert property (p_oa_overlap_rcv_ready);

  property p_oa_shadow_hold;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset || axis_tkeep_err)
      (core_busy && !$past(
        core_start
    )) |-> $stable(core_block_reg);
  endproperty
  a_oa_shadow_hold :
  assert property (p_oa_shadow_hold);

  // =========================================================
  // SVA: test_plan_overall/oa_block_pending
  // =========================================================
  // Checks both busy -> S_WAIT_CORE(block_pending=1) and idle/core_done -> S_START_CORE(block_pending=0)
  property p_oa_pending_set;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset || axis_tkeep_err)
      next_blk_ready
      |=> ($past(
        (core_busy && !core_done) || core_start
    ) ? (block_pending && state == S_WAIT_CORE) : (!block_pending && state == S_START_CORE));
  endproperty
  a_oa_pending_set :
  assert property (p_oa_pending_set);

  property p_oa_pending_handshake;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset)
      (state == S_WAIT_CORE && block_pending && core_done)
      |=> (!block_pending && state == S_START_CORE);
  endproperty
  a_oa_pending_handshake :
  assert property (p_oa_pending_handshake);

  // =========================================================
  // SVA: test_plan_overall/oa_async_done_chain
  // =========================================================
  property p_oa_global_core_done_latch;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset || axis_tkeep_err)
      core_done
      |=> (!first_block &&
           {core_state_out_reg[0], core_state_out_reg[1], core_state_out_reg[2], core_state_out_reg[3],
            core_state_out_reg[4], core_state_out_reg[5], core_state_out_reg[6], core_state_out_reg[7]} == $past(
        core_state_out
    ));
  endproperty
  a_oa_global_core_done_latch :
  assert property (p_oa_global_core_done_latch);

  // =========================================================
  // SVA: test_plan_overall/oa_overlap_abort
  // =========================================================
  property p_oa_tkeep_err_kills_core;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset)
      axis_tkeep_err
      |=> (state == S_IDLE && ret_state == S_IDLE && !block_pending &&
           !status_busy && !core_busy && status_err_flag &&
           first_block && byte_cnt == 7'd0 && msg_len == 64'd0 && core_block_reg == 512'd0 &&
           core_state_out_reg[0] == 32'd0 && core_state_out_reg[7] == 32'd0);
  endproperty
  a_oa_tkeep_err_kills_core :
  assert property (p_oa_tkeep_err_kills_core);

  // =========================================================
  // SVA: test_plan_csr/csr_busy_prot, csr_wo_err, csr_secure_prot
  // Address-independent invariants on AXI4-Lite error responses
  // =========================================================
  property p_axi_write_err_atomicity;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset) ($rose(
        s_axi_bvalid
    ) && (s_axi_bresp != 2'b00) && !$past(
        ctrl_soft_reset
    )) |-> ($stable(
        ctrl_en
    ) && $stable(
        ctrl_irq_en
    ) && !ctrl_start_pulse && !ctrl_soft_reset && $stable(
        state_in_reg[0]
    ) && $stable(
        state_in_reg[7]
    ));
  endproperty
  a_axi_write_err_atomicity :
  assert property (p_axi_write_err_atomicity);

  property p_axi_read_err_zero_mask;
    @(posedge clk_i) disable iff (!rst_n_i)
      (s_axi_rvalid && (s_axi_rresp != 2'b00)) |-> (s_axi_rdata == 32'd0);
  endproperty
  a_axi_read_err_zero_mask :
  assert property (p_axi_read_err_zero_mask);

endmodule
