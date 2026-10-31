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
//   - Implements the AXI4-Stream UVM agent lifecycle, driver selection, monitor connection, and coverage integration.
//------------------------------------------------------------------------------

class axis_agent extends uvm_agent;

  `uvm_component_utils(axis_agent)

  axis_agent_config m_cfg;
  uvm_analysis_port #(axis_seq_item) ap;

  axis_monitor m_monitor;
  uvm_sequencer #(axis_seq_item) m_sequencer;

  axis_m_driver m_driver;
  // axis_s_driver s_driver;

  axis_coverage m_fcov_monitor;

  extern function new(string name = "axis_agent", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern task reset_agent();

endclass : axis_agent

function axis_agent::new(string name = "axis_agent", uvm_component parent = null);
  super.new(name, parent);
endfunction

task axis_agent::reset_agent();
  if (m_sequencer != null) begin
    m_sequencer.stop_sequences();
  end

  if (m_cfg.is_active == UVM_ACTIVE) begin
    if (m_cfg.is_master && m_cfg.drv_m_bfm != null) begin
      m_cfg.drv_m_bfm.flush();
    end else if (!m_cfg.is_master) begin
      // Slave driver support is archived in not_used/.
    end
  end

  if (m_cfg.mon_bfm != null) begin
    m_cfg.mon_bfm.flush();
  end
endtask : reset_agent

function void axis_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  m_cfg = axis_agent_config::get_config(this);
  m_monitor = axis_monitor::type_id::create("m_monitor", this);

  if (m_cfg.is_active == UVM_ACTIVE) begin
    m_sequencer = uvm_sequencer#(axis_seq_item)::type_id::create("m_sequencer", this);

    if (m_cfg.is_master) begin
      m_driver = axis_m_driver::type_id::create("m_driver", this);
    end else begin
      // Slave driver support is archived in not_used/.
    end
  end

  if (m_cfg.has_functional_coverage) begin
    m_fcov_monitor = axis_coverage::type_id::create("m_fcov_monitor", this);
  end
endfunction

function void axis_agent::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  ap = m_monitor.ap;

  if (m_cfg.is_active == UVM_ACTIVE) begin
    if (m_cfg.is_master) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end else begin
      // Slave driver support is archived in not_used/.
    end
  end

  if (m_cfg.has_functional_coverage) begin
    m_monitor.ap.connect(m_fcov_monitor.analysis_export);
  end
endfunction
