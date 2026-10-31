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

class axi4lite_agent_config extends uvm_object;

  localparam string s_my_config_id = "axi4lite_agent_config";
  localparam string s_no_config_id = "no config";
  localparam string s_my_config_type_error_id = "config type error";

  `uvm_object_utils(axi4lite_agent_config)
  virtual axi4lite_if vif;
  virtual axi4lite_monitor_bfm mon_bfm;
  virtual axi4lite_driver_bfm drv_bfm;

  uvm_active_passive_enum active = UVM_ACTIVE;
  bit has_functional_coverage = 0;
  bit has_scoreboard = 0;
  bit enable_random_delay = 0;

  int ADDR_WIDTH = 32;
  int DATA_WIDTH = 32;
  bit disable_alignment_sva = 0;
  bit disable_timeout_sva = 0;

  extern static function axi4lite_agent_config get_config(uvm_component c);
  extern function new(string name = "axi4lite_agent_config");

endclass : axi4lite_agent_config

function axi4lite_agent_config::new(string name = "axi4lite_agent_config");
  super.new(name);
endfunction

function axi4lite_agent_config axi4lite_agent_config::get_config(uvm_component c);
  axi4lite_agent_config t;

  if (!uvm_config_db#(axi4lite_agent_config)::get(c, "", s_my_config_id, t))
    `uvm_fatal(
        "CONFIG_LOAD", $sformatf(
        "Cannot get() configuration %s from uvm_config_db. Have you set() it?", s_my_config_id))

  return t;
endfunction
