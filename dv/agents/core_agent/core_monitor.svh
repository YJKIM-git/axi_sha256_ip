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
//   - Publishes sampled SHA-256 core transactions to the verification environment.
//------------------------------------------------------------------------------

class core_monitor extends uvm_monitor;

  `uvm_component_utils(core_monitor)

  uvm_analysis_port #(core_seq_item) ap;

  virtual core_monitor_bfm           bfm;
  core_agent_config                  cfg;

  extern function new(string name = "core_monitor", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern function void notify_transaction(core_seq_item item);

endclass : core_monitor


function core_monitor::new(string name = "core_monitor", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void core_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);

  ap = new("ap", this);
  cfg = core_agent_config::get_config(this);

  if (cfg == null) begin
    `uvm_fatal("CORE_MON", "Failed to get core_agent_config from uvm_config_db")
  end

  bfm = cfg.mon_bfm;
endfunction : build_phase

function void core_monitor::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  bfm.register_proxy(this);
endfunction : connect_phase

task core_monitor::run_phase(uvm_phase phase);
  bfm.run();
endtask : run_phase

function void core_monitor::notify_transaction(core_seq_item item);
  ap.write(item);
endfunction : notify_transaction
