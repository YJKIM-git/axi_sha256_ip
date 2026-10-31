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
//   - Defines the SHA-256 basic sanity test.
//------------------------------------------------------------------------------

class sha256_sanity_test extends sha256_test_base;
  `uvm_component_utils(sha256_sanity_test)

  extern function new(string name = "sha256_sanity_test", uvm_component parent = null);
  extern task run_phase(uvm_phase phase);

endclass : sha256_sanity_test

function sha256_sanity_test::new(string name = "sha256_sanity_test", uvm_component parent = null);
  super.new(name, parent);
endfunction

task sha256_sanity_test::run_phase(uvm_phase phase);
  sha256_sanity_vseq vseq;

  phase.raise_objection(this);

  vseq          = sha256_sanity_vseq::type_id::create("vseq");

  vseq.m_cfg    = m_env_cfg;
  vseq.axil_sqr = m_env.m_axi4lite_agent.m_sequencer;
  vseq.axis_sqr = m_env.m_axis_agent.m_sequencer;

  if (!vseq.randomize()) begin
    `uvm_fatal("TEST", "Failed to randomize sanity_vseq")
  end

  `uvm_info("TEST", "Starting sha256_sanity_vseq...", UVM_LOW)
  vseq.start(null);

  #1us;

  phase.drop_objection(this);
endtask
