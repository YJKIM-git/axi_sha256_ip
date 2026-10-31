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
class axi4lite_agent extends uvm_component;

  `uvm_component_utils(axi4lite_agent)

  axi4lite_agent_config m_cfg;

  uvm_analysis_port #(axi4lite_seq_item) ap;
  axi4lite_monitor m_monitor;
  axi4lite_sequencer m_sequencer;
  axi4lite_driver m_driver;
  axi4lite_coverage_monitor m_fcov_monitor;

  extern function new(string name = "axi4lite_agent", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

endclass : axi4lite_agent


function axi4lite_agent::new(string name = "axi4lite_agent", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void axi4lite_agent::build_phase(uvm_phase phase);
  m_cfg = axi4lite_agent_config::get_config(this);

  if (m_cfg.DATA_WIDTH != 32 && m_cfg.DATA_WIDTH != 64) begin
    `uvm_fatal("CFG_ERR", $sformatf("Unsupported DATA_WIDTH: %0d", m_cfg.DATA_WIDTH))
  end

  m_monitor = axi4lite_monitor::type_id::create("m_monitor", this);
  m_monitor.m_cfg = m_cfg;

  if (m_cfg.active == UVM_ACTIVE) begin
    m_driver = axi4lite_driver::type_id::create("m_driver", this);
    m_driver.m_cfg = m_cfg;
    m_sequencer = axi4lite_sequencer::type_id::create("m_sequencer", this);
  end

  if (m_cfg.has_functional_coverage) begin
    m_fcov_monitor = axi4lite_coverage_monitor::type_id::create("m_fcov_monitor", this);
  end
endfunction : build_phase

function void axi4lite_agent::connect_phase(uvm_phase phase);
  ap = m_monitor.ap;

  if (m_cfg.active == UVM_ACTIVE) begin
    m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
  end

  if (m_cfg.has_functional_coverage) begin
    m_monitor.ap.connect(m_fcov_monitor.analysis_export);
  end

  if (m_cfg.vif != null) begin
    m_cfg.vif.cfg_data_width = m_cfg.DATA_WIDTH;
    m_cfg.vif.cfg_addr_width = m_cfg.ADDR_WIDTH;
    m_cfg.vif.disable_alignment_sva = m_cfg.disable_alignment_sva;
    m_cfg.vif.disable_timeout_sva = m_cfg.disable_timeout_sva;
  end else begin
    `uvm_error("VIF_ERROR", "Virtual interface in axi4lite_agent_config is null")
  end
endfunction : connect_phase
