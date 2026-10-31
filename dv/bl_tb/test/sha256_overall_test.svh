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
//   - Defines the SHA-256 end-to-end integration test.
//------------------------------------------------------------------------------

class sha256_overall_test extends sha256_test_base;
  `uvm_component_utils(sha256_overall_test)

  extern function new(string name = "sha256_overall_test", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);

endclass : sha256_overall_test

function sha256_overall_test::new(string name = "sha256_overall_test", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void sha256_overall_test::build_phase(uvm_phase phase);
  super.build_phase(phase);
  m_axi4lite_agent_cfg.enable_random_delay = 1;
  m_axi4lite_agent_cfg.disable_timeout_sva = 0;
  m_env_cfg.enable_sb_check = 1;
endfunction

task sha256_overall_test::run_phase(uvm_phase phase);
  sha256_overall_vseq vseq;
  uvm_top.set_timeout(50ms, 0);
  phase.raise_objection(this);

  vseq = sha256_overall_vseq::type_id::create("vseq");
  vseq.m_cfg    = m_env_cfg;
  vseq.m_axis_agent = m_env.m_axis_agent;
  vseq.axil_sqr = m_env.m_axi4lite_agent.m_sequencer;
  vseq.axis_sqr = m_env.m_axis_agent.m_sequencer;

  if (!vseq.randomize()) begin
    `uvm_fatal("TEST", "Failed to randomize sha256_overall_vseq")
  end

  `uvm_info("TEST", "Starting sha256_overall_vseq to execute Overall Test Plan...", UVM_LOW)

  vseq.start(null);
  #5us;

  phase.drop_objection(this);
endtask
