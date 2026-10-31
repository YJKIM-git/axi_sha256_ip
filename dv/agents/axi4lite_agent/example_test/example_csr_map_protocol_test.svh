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
//   - Completely rewrote the protocol-specific logic, interfaces, and sequences for the AXI4-Lite protocol.
//------------------------------------------------------------------------------

//
// Class Description:
//
//
class example_csr_map_protocol_test extends example_csr_map_test_base;
  `uvm_component_utils(example_csr_map_protocol_test)

  function new(string name = "example_csr_map_protocol_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_axi4lite_agent_cfg.enable_random_delay = 1;
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi4lite_protocol_cov_seq protocol_seq;

    phase.raise_objection(this);

    protocol_seq = axi4lite_protocol_cov_seq::type_id::create("protocol_seq");
    if (!protocol_seq.randomize()) begin
      `uvm_fatal("TEST", "Failed to randomize protocol_seq")
    end
    protocol_seq.start(m_env_cfg.csr_rb.default_map.get_sequencer());

    phase.drop_objection(this);
  endtask
endclass
