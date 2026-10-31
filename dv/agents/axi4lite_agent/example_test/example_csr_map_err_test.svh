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
class example_csr_map_err_test extends example_csr_map_test_base;
  `uvm_component_utils(example_csr_map_err_test)

  function new(string name = "example_csr_map_err_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi4lite_err_inject_seq err_inject_seq;
    uvm_status_e status;
    uvm_reg_data_t rdata;

    phase.raise_objection(this);

    m_env_cfg.csr_rb.CONTROL.mode.set(3);
    m_env_cfg.csr_rb.CONTROL.update(status);

    m_env_cfg.csr_rb.TRIGGER.start.set(1);
    m_env_cfg.csr_rb.TRIGGER.update(status);

    err_inject_seq = axi4lite_err_inject_seq::type_id::create("err_inject_seq");
    if (!err_inject_seq.randomize()) begin
      `uvm_fatal("TEST", "Failed to randomize err_inject_seq")
    end
    err_inject_seq.start(m_env_cfg.csr_rb.default_map.get_sequencer());

    m_env_cfg.csr_rb.STATUS.read(status, rdata);

    m_env_cfg.csr_rb.TRIGGER.stop.set(1);
    m_env_cfg.csr_rb.TRIGGER.update(status);

    phase.drop_objection(this);
  endtask
endclass
