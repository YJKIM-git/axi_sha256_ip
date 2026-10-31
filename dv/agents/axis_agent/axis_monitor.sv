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
//   - Publishes reassembled AXI4-Stream monitor transactions to the SHA-256 UVM environment.
//------------------------------------------------------------------------------

class axis_monitor extends uvm_monitor;

  `uvm_component_utils(axis_monitor)

  uvm_analysis_port #(axis_seq_item) ap;

  virtual axis_monitor_if bfm;
  axis_agent_config cfg;

  extern function new(string name = "axis_monitor", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern function void check_phase(uvm_phase phase);
  extern function void notify_transaction(axis_seq_item item);

endclass : axis_monitor

function axis_monitor::new(string name = "axis_monitor", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void axis_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);

  ap  = new("ap", this);
  cfg = axis_agent_config::get_config(this);
  bfm = cfg.mon_bfm;
endfunction : build_phase

function void axis_monitor::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  bfm.register_proxy(this);
endfunction : connect_phase

task axis_monitor::run_phase(uvm_phase phase);
  forever begin
    fork
      begin
        bfm.run();
      end
      begin
        @(negedge bfm.aresetn);

        if (bfm.active_pkts.size() > 0) begin
          foreach (bfm.active_pkts[i]) begin
            bfm.active_pkts[i].status = axis_seq_item::INCOMPLETE;
            notify_transaction(bfm.active_pkts[i]);
          end
          bfm.active_pkts.delete();
        end
      end
    join_any

    disable fork;

    if (bfm.aresetn !== 1'b1) begin
      @(posedge bfm.aresetn);
    end
  end
endtask

function void axis_monitor::check_phase(uvm_phase phase);
  string err_msg;

  super.check_phase(phase);

  if (cfg.en_protocol_check && bfm.active_pkts.size() > 0) begin
    err_msg = $sformatf(
        "AXI4STREAM_ERRM_STREAM_ALL_DONE_EOS: %0d incomplete packets remain at End Of Simulation.",
        bfm.active_pkts.size()
    );
    `uvm_error("AXIS_PROTOCOL_ERR", err_msg)
  end
endfunction : check_phase

function void axis_monitor::notify_transaction(axis_seq_item item);
  ap.write(item);
endfunction : notify_transaction
