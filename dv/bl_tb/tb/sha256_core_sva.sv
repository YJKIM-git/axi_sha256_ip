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
//   - Defines white-box assertions for SHA-256 core control, latency, and reset behavior.
//------------------------------------------------------------------------------

module sha256_core_sva (
    input logic         clk_i,
    input logic         rst_n_i,
    input logic         start_i,
    input logic         ready_o,
    input logic         busy_o,
    input logic         done_o,
    input logic         init_o,
    input logic         pre_round_o,
    input logic         load_block_o,
    input logic         round_en_o,
    input logic         update_o,
    input logic [  5:0] round_idx_o,
    input logic [511:0] block_i,
    input logic [255:0] state_in_i
);
  // =========================================================
  // SVA: test_plan_core/ctrl_start, ctrl_busy, ctrl_done, ctrl_latency
  //                     ctrl_mutex, ctrl_stable, ctrl_done_pulse
  // =========================================================
  property p_ctrl_start;
    @(posedge clk_i) disable iff (!rst_n_i) (start_i && ready_o) |=> (!ready_o && busy_o);
  endproperty
  a_ctrl_start :
  assert property (p_ctrl_start);

  property p_ctrl_busy;
    @(posedge clk_i) disable iff (!rst_n_i) busy_o |-> (!ready_o && !done_o);
  endproperty
  a_ctrl_busy :
  assert property (p_ctrl_busy);

  property p_ctrl_done;
    @(posedge clk_i) disable iff (!rst_n_i) done_o |=> (!busy_o && ready_o);
  endproperty
  a_ctrl_done :
  assert property (p_ctrl_done);

  property p_ctrl_latency;
    @(posedge clk_i) disable iff (!rst_n_i) (start_i && ready_o) |=> ##68 done_o;
  endproperty
  a_ctrl_latency :
  assert property (p_ctrl_latency);

  property p_ctrl_mutex;
    @(posedge clk_i) disable iff (!rst_n_i) !(ready_o && busy_o);
  endproperty
  a_ctrl_mutex :
  assert property (p_ctrl_mutex);

  property p_ctrl_stable;
    @(posedge clk_i) disable iff (!rst_n_i) busy_o |-> $stable(
        block_i
    ) && $stable(
        state_in_i
    );
  endproperty
  a_ctrl_stable :
  assert property (p_ctrl_stable);

  property p_ctrl_done_pulse;
    @(posedge clk_i) disable iff (!rst_n_i) done_o |=> !done_o;
  endproperty
  a_ctrl_done_pulse :
  assert property (p_ctrl_done_pulse);


  // =========================================================
  // SVA: test_plan_core/fsm_seq, fsm_duration
  // =========================================================
  property p_fsm_sequence;
    @(posedge clk_i) disable iff (!rst_n_i)
      init_o |=> pre_round_o |=> round_en_o [*64] |=> update_o |=> done_o;
  endproperty
  a_fsm_sequence :
  assert property (p_fsm_sequence);

  property p_fsm_duration;
    @(posedge clk_i) disable iff (!rst_n_i)
      (round_en_o && round_idx_o < 63) |=> (round_idx_o == $past(
        round_idx_o
    ) + 1);
  endproperty
  a_fsm_duration :
  assert property (p_fsm_duration);

endmodule
