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
//   - Defines core-agent configuration used by the SHA-256 core verification environment.
//------------------------------------------------------------------------------

class core_agent_config extends uvm_object;

  localparam string s_my_config_id = "core_agent_config";
  localparam string s_no_config_id = "no config";
  localparam string s_my_config_type_error_id = "config type error";

  `uvm_object_utils(core_agent_config)
  virtual core_monitor_bfm mon_bfm;

  uvm_active_passive_enum  is_active    = UVM_PASSIVE;
  bit                      has_coverage = 1;

  function new(string name = "core_agent_config");
    super.new(name);
  endfunction

  static function core_agent_config get_config(uvm_component c);
    core_agent_config t;
    if (!uvm_config_db#(core_agent_config)::get(c, "", s_my_config_id, t)) begin
      `uvm_fatal("CFG_ERR", "Cannot get core_agent_config from uvm_config_db")
    end
    return t;
  endfunction

endclass : core_agent_config
