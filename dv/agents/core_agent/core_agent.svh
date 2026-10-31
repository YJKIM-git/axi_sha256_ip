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
//   - Implements the SHA-256 core UVM agent lifecycle and monitor integration.
//------------------------------------------------------------------------------

class core_agent extends uvm_agent;
  `uvm_component_utils(core_agent)

  core_agent_config cfg;
  core_monitor      monitor;
  core_coverage     coverage;

  extern function new(string name = "core_agent", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
endclass : core_agent

function core_agent::new(string name = "core_agent", uvm_component parent = null);
  super.new(name, parent);
endfunction

function void core_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  cfg = core_agent_config::get_config(this);
  uvm_config_db #(core_agent_config)::set(this, "monitor", "core_agent_config", cfg);

  monitor = core_monitor::type_id::create("monitor", this);

  if (cfg.has_coverage) begin
    uvm_config_db #(core_agent_config)::set(this, "coverage", "core_agent_config", cfg);
    coverage = core_coverage::type_id::create("coverage", this);
  end
endfunction

function void core_agent::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  if (cfg.has_coverage) begin
    monitor.ap.connect(coverage.analysis_export);
  end
endfunction
