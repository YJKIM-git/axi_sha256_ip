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
    input logic [63:0] msg_len,
    input logic [ 6:0] byte_cnt,
    input logic        first_block,
    input logic [ 7:0] block_b           [0:63],
    input logic        transaction_active,

    // Test Plan Coverage Check Ports
    input logic       status_err_flag,
    input logic       slv_reg_wren,
    input logic [7:0] awaddr_reg,
    input logic       slv_reg_rden,
    input logic [7:0] araddr_reg,
    input logic       core_done,
    input logic       s_axis_tlast,
    input logic       clear_done_pulse
);

  // =========================================================
  // SVA: test_plan_csr/csr_pulse_clear
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


  // =========================================================
  // SVA: test_plan_overall/oa_zeroization, oa_latency, oa_recovery
  // =========================================================
  property p_oa_zeroization;
    @(posedge clk_i) disable iff (!rst_n_i)
      (state == 3'd0) |-> (block_b[0] == 8'h00 && block_b[63] == 8'h00);
  endproperty
  a_oa_zeroization :
  assert property (p_oa_zeroization);

  property p_oa_latency;
    @(posedge clk_i) disable iff (!rst_n_i || ctrl_soft_reset)
      (state == 3'd4 && ret_state == 3'd6) |=> ##71 status_done;
  endproperty
  a_oa_latency :
  assert property (p_oa_latency);

  property p_oa_recovery;
    @(posedge clk_i) disable iff (!rst_n_i)
      ctrl_soft_reset |=> (state == 3'd0 && !transaction_active && !status_busy &&
                           !status_done && first_block && byte_cnt == 7'd0 && msg_len == 64'd0);
  endproperty
  a_oa_recovery :
  assert property (p_oa_recovery);

  // =========================================================
  // SVA: test_plan_overall/oa_lifecycle
  // =========================================================

  property p_lifecycle_irq_behavior;
    @(posedge clk_i) disable iff (!rst_n_i) (status_done && ctrl_irq_en) |-> irq_o;
  endproperty
  a_lifecycle_irq_behavior :
  assert property (p_lifecycle_irq_behavior);

  property p_lifecycle_irq_clear;
    @(posedge clk_i) disable iff (!rst_n_i) clear_done_pulse |=> (!status_done && !irq_o);
  endproperty
  a_lifecycle_irq_clear :
  assert property (p_lifecycle_irq_clear);


endmodule
