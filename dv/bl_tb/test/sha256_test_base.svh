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
//   - Provides common configuration, environment construction, and result reporting for SHA-256 tests.
//------------------------------------------------------------------------------

class sha256_test_base extends uvm_test;
  `uvm_component_utils(sha256_test_base)

  sha256_env            m_env;
  sha256_env_config     m_env_cfg;

  axi4lite_agent_config m_axi4lite_agent_cfg;
  axis_agent_config     m_axis_agent_cfg;
  core_agent_config     m_core_agent_cfg;

  extern function new(string name = "sha256_test_base", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

endclass : sha256_test_base

function sha256_test_base::new(string name = "sha256_test_base", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void sha256_test_base::build_phase(uvm_phase phase);
  virtual intr_bfm v_intr_bfm;
  virtual rst_bfm  v_rst_bfm;
  super.build_phase(phase);

  m_env_cfg = sha256_env_config::type_id::create("m_env_cfg");
  m_env_cfg.csr_rb = new("csr_rb");
  m_env_cfg.csr_rb.build();
  m_env_cfg.csr_rb.lock_model();

  // =========================================================
  // 1. AXI4-Lite Agent
  // =========================================================
  m_axi4lite_agent_cfg = axi4lite_agent_config::type_id::create("m_axi4lite_agent_cfg");
  m_axi4lite_agent_cfg.active = UVM_ACTIVE;
  m_axi4lite_agent_cfg.has_functional_coverage = 1;
  m_axi4lite_agent_cfg.has_scoreboard = 1;
  m_axi4lite_agent_cfg.ADDR_WIDTH = 32;
  m_axi4lite_agent_cfg.DATA_WIDTH = 32;
  m_axi4lite_agent_cfg.disable_alignment_sva = 0;
  m_axi4lite_agent_cfg.disable_timeout_sva = 0;
  m_axi4lite_agent_cfg.enable_random_delay = 0;

  if (!uvm_config_db#(virtual axi4lite_monitor_bfm)::get(
          this, "", "AXI4LITE_mon_bfm", m_axi4lite_agent_cfg.mon_bfm
      )) begin
    `uvm_fatal("CFG", "AXI4LITE_mon_bfm not found in uvm_config_db")
  end
  if (!uvm_config_db#(virtual axi4lite_driver_bfm)::get(
          this, "", "AXI4LITE_drv_bfm", m_axi4lite_agent_cfg.drv_bfm
      )) begin
    `uvm_fatal("CFG", "AXI4LITE_drv_bfm not found in uvm_config_db")
  end
  if (!uvm_config_db#(virtual axi4lite_if)::get(
          this, "", "AXI4LITE_vif", m_axi4lite_agent_cfg.vif
      )) begin
    `uvm_info("CFG", "AXI4LITE_vif not found in uvm_config_db; continuing with minimal bring-up",
              UVM_LOW)
  end

  // =========================================================
  // 2. AXIS Agent
  // =========================================================
  m_axis_agent_cfg = axis_agent_config::type_id::create("m_axis_agent_cfg");
  m_axis_agent_cfg.is_active = UVM_ACTIVE;
  m_axis_agent_cfg.has_functional_coverage = 1;
  m_axis_agent_cfg.is_master = 1;
  if (!uvm_config_db#(virtual axis_monitor_if)::get(
          this, "", "AXIS_mon_bfm", m_axis_agent_cfg.mon_bfm
      )) begin
    `uvm_info("CFG", "AXIS_mon_bfm not found in uvm_config_db; continuing with minimal bring-up",
              UVM_LOW)
  end
  if (!uvm_config_db#(virtual axis_m_driver_if)::get(
          this, "", "AXIS_drv_bfm", m_axis_agent_cfg.drv_m_bfm
      )) begin
    `uvm_info("CFG", "AXIS_drv_bfm not found in uvm_config_db; continuing with minimal bring-up",
              UVM_LOW)
  end

  // =========================================================
  // 3. CORE Agent
  // =========================================================
  m_core_agent_cfg = core_agent_config::type_id::create("m_core_agent_cfg");
  if (!uvm_config_db#(virtual core_monitor_bfm)::get(
          this, "", "CORE_mon_bfm", m_core_agent_cfg.mon_bfm
      )) begin
    `uvm_info("CFG", "CORE_mon_bfm not found in uvm_config_db; continuing with minimal bring-up",
              UVM_LOW)
  end

  // =========================================================
  // 4. INTR / RST Utility
  // =========================================================
  if (!uvm_config_db#(virtual intr_bfm)::get(this, "", "INTR_bfm", v_intr_bfm)) begin
    `uvm_fatal("CFG", "INTR_bfm not found in uvm_config_db")
  end
  m_env_cfg.m_intr_util = intr_util::type_id::create("m_intr_util");
  m_env_cfg.m_intr_util.set_bfm(v_intr_bfm);

  if (!uvm_config_db#(virtual rst_bfm)::get(this, "", "RST_bfm", v_rst_bfm)) begin
    `uvm_fatal("CFG", "RST_bfm not found in uvm_config_db")
  end
  m_env_cfg.m_rst_util = rst_util::type_id::create("m_rst_util");
  m_env_cfg.m_rst_util.set_bfm(v_rst_bfm);

  // =========================================================
  // 5. Set Configurations to uvm_config_db
  // =========================================================
  m_env_cfg.axi4lite_agent_cfg = m_axi4lite_agent_cfg;
  m_env_cfg.axis_agent_cfg = m_axis_agent_cfg;
  m_env_cfg.core_agent_cfg = m_core_agent_cfg;

  uvm_config_db#(sha256_env_config)::set(this, "*", "sha256_env_config", m_env_cfg);
  uvm_config_db#(axi4lite_agent_config)::set(this, "*", "axi4lite_agent_config",
                                             m_axi4lite_agent_cfg);
  uvm_config_db#(axis_agent_config)::set(this, "*", "axis_agent_config", m_axis_agent_cfg);
  uvm_config_db#(core_agent_config)::set(this, "*", "core_agent_config", m_core_agent_cfg);

  m_env = sha256_env::type_id::create("m_env", this);
endfunction

function void sha256_test_base::report_phase(uvm_phase phase);
  uvm_coreservice_t cs = uvm_coreservice_t::get();
  uvm_report_server svr = cs.get_report_server();

  if (svr.get_severity_count(UVM_ERROR) == 0 && svr.get_severity_count(UVM_FATAL) == 0) begin
    `uvm_info("TEST_RESULT", "=== SHA256 UVM TEST PASSED ===", UVM_NONE)
  end else begin
    `uvm_error("TEST_RESULT", "=== SHA256 UVM TEST FAILED ===")
  end
endfunction
