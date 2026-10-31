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
//   - Connects AXI4-Stream master sequence items to the master driver BFM in the SHA-256 UVM agent.
//------------------------------------------------------------------------------

class axis_m_driver extends uvm_driver #(axis_seq_item);

  `uvm_component_utils(axis_m_driver)

  axis_agent_config m_cfg;
  virtual axis_m_driver_if v_bfm;

  extern function new(string name = "axis_m_driver", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern task process_transactions();

endclass : axis_m_driver

function axis_m_driver::new(string name = "axis_m_driver", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void axis_m_driver::build_phase(uvm_phase phase);
  super.build_phase(phase);
  m_cfg = axis_agent_config::get_config(this);
  v_bfm = m_cfg.drv_m_bfm;
endfunction

task axis_m_driver::run_phase(uvm_phase phase);
  fork
    v_bfm.wait_for_reset();
    v_bfm.drive_bus(m_cfg);
    process_transactions();
  join
endtask

task axis_m_driver::process_transactions();
  bit completed;

  forever begin
    seq_item_port.get_next_item(req);
    v_bfm.push_transaction(req);
    v_bfm.wait_pkt_done(req.tid, m_cfg.timeout_cycles, completed);
    if (!completed) begin
      `uvm_error("AXIS_M_DRIVER",
                 $sformatf("Packet completion timeout for tid=0x%0h", req.tid))
    end
    seq_item_port.item_done();
  end
endtask
