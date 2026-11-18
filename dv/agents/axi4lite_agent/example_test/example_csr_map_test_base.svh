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
class example_csr_map_test_base extends uvm_test;
  `uvm_component_utils(example_csr_map_test_base)

  example_csr_map_env m_env;
  example_csr_map_env_config m_env_cfg;
  axi4lite_agent_config m_axi4lite_agent_cfg;

  function new(string name = "example_csr_map_test_base", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    m_env_cfg = example_csr_map_env_config::type_id::create("m_env_cfg");

    m_env_cfg.csr_rb = new("csr_rb");
    m_env_cfg.csr_rb.build();
    m_env_cfg.csr_rb.lock_model();

    m_axi4lite_agent_cfg = axi4lite_agent_config::type_id::create("m_axi4lite_agent_cfg");

    m_axi4lite_agent_cfg.active = UVM_ACTIVE;
    m_axi4lite_agent_cfg.has_functional_coverage = 1;
    m_axi4lite_agent_cfg.has_scoreboard = 1;
    m_axi4lite_agent_cfg.ADDR_WIDTH = 32;
    m_axi4lite_agent_cfg.DATA_WIDTH = 32;

    if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", m_axi4lite_agent_cfg.vif)) begin
      `uvm_fatal("CFG", "vif not found in uvm_config_db")
    end

    if (!uvm_config_db#(virtual axi4lite_monitor_bfm)::get(
            this, "", "mon_bfm", m_axi4lite_agent_cfg.mon_bfm
        )) begin
      `uvm_fatal("CFG", "mon_bfm not found in uvm_config_db")
    end

    if (!uvm_config_db#(virtual axi4lite_driver_bfm)::get(
            this, "", "drv_bfm", m_axi4lite_agent_cfg.drv_bfm
        )) begin
      `uvm_fatal("CFG", "drv_bfm not found in uvm_config_db")
    end

    m_env_cfg.m_axi4lite_agent_cfg = m_axi4lite_agent_cfg;
    m_axi4lite_agent_cfg.disable_alignment_sva = 1;
    m_axi4lite_agent_cfg.disable_timeout_sva = 1;
    m_axi4lite_agent_cfg.enable_random_delay = 0;

    uvm_config_db#(example_csr_map_env_config)::set(this, "*", "example_csr_map_env_config", m_env_cfg);
    uvm_config_db#(axi4lite_agent_config)::set(this, "*", "agent_config", m_axi4lite_agent_cfg);

    m_env = example_csr_map_env::type_id::create("m_env", this);
  endfunction

  virtual function void report_phase(uvm_phase phase);
    uvm_coreservice_t cs = uvm_coreservice_t::get();
    uvm_report_server svr = cs.get_report_server();

    if (svr.get_severity_count(UVM_ERROR) == 0 && svr.get_severity_count(UVM_FATAL) == 0) begin
      `uvm_info("TEST_RESULT", "=== UVM TEST PASSED ===", UVM_NONE)
    end else begin
      `uvm_error("TEST_RESULT", "=== UVM TEST FAILED ===")
    end
  endfunction
endclass
