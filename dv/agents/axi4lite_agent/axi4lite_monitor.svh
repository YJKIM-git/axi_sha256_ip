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
class axi4lite_monitor extends uvm_component;

  `uvm_component_utils(axi4lite_monitor)

  virtual axi4lite_monitor_bfm m_bfm;

  axi4lite_agent_config m_cfg;

  uvm_analysis_port #(axi4lite_seq_item) ap;

  extern function new(string name = "axi4lite_monitor", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);

  extern function void notify_transaction(axi4lite_seq_item item);

endclass : axi4lite_monitor

function axi4lite_monitor::new(string name = "axi4lite_monitor", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void axi4lite_monitor::build_phase(uvm_phase phase);
  m_cfg = axi4lite_agent_config::get_config(this);
  m_bfm = m_cfg.mon_bfm;
  m_bfm.proxy = this;

  ap = new("ap", this);
endfunction : build_phase

task axi4lite_monitor::run_phase(uvm_phase phase);
  m_bfm.run();
endtask : run_phase

function void axi4lite_monitor::report_phase(uvm_phase phase);

endfunction : report_phase

function void axi4lite_monitor::notify_transaction(axi4lite_seq_item item);
  if (m_cfg.DATA_WIDTH == 32) begin
    item.rdata &= 64'h00000000FFFFFFFF;
    item.wdata &= 64'h00000000FFFFFFFF;
  end
  ap.write(item);
endfunction : notify_transaction
