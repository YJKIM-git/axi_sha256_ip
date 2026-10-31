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
//   - Defines the SHA-256 AXI4-Stream directed coverage test.
//------------------------------------------------------------------------------

class sha256_axis_test extends sha256_test_base;
  `uvm_component_utils(sha256_axis_test)

  extern function new(string name = "sha256_axis_test", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
endclass : sha256_axis_test

function sha256_axis_test::new(string name = "sha256_axis_test", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void sha256_axis_test::build_phase(uvm_phase phase);
  super.build_phase(phase);

  m_env_cfg.enable_sb_check = 0;
  m_axi4lite_agent_cfg.enable_random_delay = 1;
  m_axi4lite_agent_cfg.disable_timeout_sva = 0;
endfunction

task sha256_axis_test::run_phase(uvm_phase phase);
  sha256_axis_vseq vseq;

  uvm_top.set_timeout(100ms, 0);

  phase.phase_done.set_drain_time(this, 1us);
  phase.raise_objection(this);

  vseq              = sha256_axis_vseq::type_id::create("vseq");
  vseq.m_cfg        = m_env_cfg;
  vseq.m_axis_agent = m_env.m_axis_agent;
  vseq.axil_sqr     = m_env.m_axi4lite_agent.m_sequencer;
  vseq.axis_sqr     = m_env.m_axis_agent.m_sequencer;

  if (!vseq.randomize()) begin
    `uvm_fatal("TEST", "Failed to randomize sha256_axis_vseq")
  end

  `uvm_info("TEST", "Starting Directed AXI-Stream Coverage Test...", UVM_LOW)
  vseq.start(null);

  phase.drop_objection(this);
endtask
