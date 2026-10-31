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
//   - Defines SHA-256 core data-pattern and reset-recovery functional coverage.
//------------------------------------------------------------------------------

class core_coverage extends uvm_subscriber #(core_seq_item);

  `uvm_component_utils(core_coverage)

  core_agent_config cfg;

  covergroup cg_dp with function sample (
      bit is_zero, bit is_one, bit is_w1, bit is_w0, bit is_chain
  );
    option.per_instance = 1;

    cp_zero: coverpoint is_zero {bins hit = {1};}
    cp_one: coverpoint is_one {bins hit = {1};}
    cp_w1: coverpoint is_w1 {bins hit = {1};}
    cp_w0: coverpoint is_w0 {bins hit = {1};}
    cp_chain: coverpoint is_chain {bins single_block = {0}; bins chained_block = {1};}
  endgroup

  covergroup cg_rst with function sample (bit aborted, int ab_cycle, logic [5:0] ab_round);
    option.per_instance = 1;

    cp_is_aborted: coverpoint aborted {bins normal = {0}; bins aborted = {1};}
    cp_aborted_cycle: coverpoint ab_cycle iff (aborted) {bins cycles[] = {[0 : 68]};}
    cp_aborted_round: coverpoint ab_round iff (aborted) {bins rounds[] = {[0 : 63]};}
  endgroup

  extern function new(string name = "core_coverage", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern virtual function void write(core_seq_item t);

  extern function bit check_walking_1(logic [511:0] val);
  extern function bit check_walking_0(logic [511:0] val);

endclass : core_coverage


function core_coverage::new(string name = "core_coverage", uvm_component parent = null);
  super.new(name, parent);
  cg_dp  = new();
  cg_rst = new();
endfunction

function void core_coverage::build_phase(uvm_phase phase);
  super.build_phase(phase);
  cfg = core_agent_config::get_config(this);
  if (cfg == null) begin
    `uvm_fatal("COV", "Failed to get core_agent_config")
  end
endfunction

// Power-of-two bitwise check for 512-bit 1-hot (Walking-1) and 1-cold (Walking-0) patterns
function bit core_coverage::check_walking_1(logic [511:0] val);
  return (val != 0) && ((val & (val - 1)) == 0);
endfunction

function bit core_coverage::check_walking_0(logic [511:0] val);
  return (~val != 0) && ((~val & (~val - 1)) == 0);
endfunction

function void core_coverage::write(core_seq_item t);
  bit is_zero, is_one, is_w1, is_w0, is_chain;

  cg_rst.sample(t.is_aborted, t.aborted_cycle, t.aborted_round);

  // Sample datapath patterns and block chaining only on completed (non-aborted) operations
  if (!t.is_aborted) begin
    is_zero  = (t.block_i == '0);
    is_one   = (t.block_i == '1);
    is_w1    = check_walking_1(t.block_i);
    is_w0    = check_walking_0(t.block_i);
    is_chain = !(t.first_block);

    cg_dp.sample(is_zero, is_one, is_w1, is_w0, is_chain);
  end
endfunction
