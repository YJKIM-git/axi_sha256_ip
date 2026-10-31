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
//   - Defines the SHA-256 core virtual interface used for monitor sampling and verification.
//------------------------------------------------------------------------------

interface core_if (
    input logic clk_i,
    input logic rst_n_i
);

  logic         start_i;
  logic         ready_o;
  logic         busy_o;
  logic         done_o;
  logic [511:0] block_i;
  logic [255:0] state_in_i;
  logic [255:0] state_out_o;

  logic         load_block_o;
  logic         init_o;
  logic         pre_round_o;
  logic         round_en_o;
  logic         update_o;
  logic [  5:0] round_idx_o;
  logic         first_block;

  clocking mon_cb @(posedge clk_i);
    default input #1step;
    input start_i;
    input ready_o;
    input busy_o;
    input done_o;
    input block_i;
    input state_in_i;
    input state_out_o;
    input load_block_o;
    input init_o;
    input pre_round_o;
    input round_en_o;
    input update_o;
    input round_idx_o;
    input first_block;
  endclocking

  modport MON(clocking mon_cb, input clk_i, rst_n_i);



  // =========================================================
  // SVA: test_plan_core/rst_basic, rst_acitve
  // =========================================================
  property p_rst_basic;
    @(posedge clk_i) !rst_n_i |-> (ready_o == 1'b1 && busy_o == 1'b0 && done_o == 1'b0);
  endproperty
  a_rst_basic :
  assert property (p_rst_basic);

  property p_rst_active;
    @(posedge clk_i) (!rst_n_i ##1 !rst_n_i) |-> ($stable(
        ready_o
    ) && $stable(
        busy_o
    ) && $stable(
        done_o
    ));
  endproperty
  a_rst_active :
  assert property (p_rst_active);


  // =========================================================
  // SVA: test_plan_core/ctrl_no_x
  // =========================================================
  property p_ctrl_no_x;
    @(posedge clk_i) disable iff (!rst_n_i) !$isunknown(
        {start_i, ready_o, busy_o, done_o}
    );
  endproperty
  a_ctrl_no_x :
  assert property (p_ctrl_no_x);

endinterface : core_if
