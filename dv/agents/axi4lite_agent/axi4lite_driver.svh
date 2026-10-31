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

class axi4lite_driver extends uvm_driver #(axi4lite_seq_item);

  `uvm_component_utils(axi4lite_driver)

  virtual axi4lite_driver_bfm m_bfm;
  axi4lite_agent_config m_cfg;

  //------------------------------------------
  // Methods
  //------------------------------------------
  extern function new(string name = "axi4lite_driver", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

endclass : axi4lite_driver

function axi4lite_driver::new(string name = "axi4lite_driver", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void axi4lite_driver::build_phase(uvm_phase phase);
  super.build_phase(phase);
  m_cfg = axi4lite_agent_config::get_config(this);
  m_bfm = m_cfg.drv_bfm;
  m_bfm.m_cfg = m_cfg;
endfunction : build_phase

task axi4lite_driver::run_phase(uvm_phase phase);
  axi4lite_seq_item req;

  m_bfm.m_cfg = m_cfg;
  m_bfm.wait_for_reset();

  forever begin
    seq_item_port.get_next_item(req);

    if (req.dir == axi4lite_seq_item::WRITE) begin
      m_bfm.drive_write(req);
    end else begin
      m_bfm.drive_read(req);
    end

    seq_item_port.item_done();
  end
endtask : run_phase
