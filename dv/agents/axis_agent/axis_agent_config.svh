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
//   - Maintains AXI4-Stream agent configuration and runtime topology controls for the SHA-256 verification environment.
//------------------------------------------------------------------------------

typedef enum bit {
  ARB_RR,
  ARB_RANDOM
} axis_arb_mode_e;

class axis_agent_config extends uvm_object;
  localparam string SMyConfigId = "axis_agent_config";
  localparam string SNoConfigId = "no config";
  localparam string SMyConfigTypeErrorId = "config type error";

  `uvm_object_utils(axis_agent_config)

  localparam int DataWidth = 1024;
  localparam int UserWidth = 1024;
  localparam int IdWidth = 32;
  localparam int DestWidth = 32;

  virtual axis_m_driver_if drv_m_bfm;
  // virtual axis_s_driver_if drv_s_bfm;
  virtual axis_monitor_if mon_bfm;

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit has_functional_coverage = 0;
  bit has_scoreboard = 0;
  bit is_master = 1;

  axis_arb_mode_e arb_mode = ARB_RR;
  int timeout_cycles = 1000;
  int active_data_width = 32;
  int active_user_width = 32;
  int active_id_max = 7;
  int active_dest_max = 7;

  bit en_protocol_check = 1'b1;
  int default_ipg = 0;

  extern function void apply_to_item(ref axis_seq_item item);
  extern function new(string name = "axis_agent_config");
  extern static function axis_agent_config get_config(uvm_component c);

endclass : axis_agent_config

function void axis_agent_config::apply_to_item(ref axis_seq_item item);
  item.active_data_width = active_data_width;
  item.active_user_width = active_user_width;
  item.active_id_max = active_id_max;
  item.active_dest_max = active_dest_max;
  item.active_byte_mask = '0;
  for (int b = 0; b < ((active_data_width + 7) / 8); b++) begin
    item.active_byte_mask[b] = 1'b1;
  end
endfunction

function axis_agent_config::new(string name = "axis_agent_config");
  super.new(name);
endfunction

function axis_agent_config axis_agent_config::get_config(uvm_component c);
  axis_agent_config t;

  if (!uvm_config_db#(axis_agent_config)::get(c, "", SMyConfigId, t)) begin
    `uvm_fatal("CONFIG_LOAD",
               $sformatf("Cannot get() configuration %s from uvm_config_db. Have you set() it?",
                         SMyConfigId))
  end

  return t;
endfunction
