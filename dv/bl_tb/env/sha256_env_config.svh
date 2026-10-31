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
//   - Defines configuration data shared by the SHA-256 block-level UVM environment.
//------------------------------------------------------------------------------

class sha256_env_config extends uvm_object;
  localparam string SMyConfigId = "sha256_env_config";
  localparam string SNoConfigId = "no config";
  localparam string SMyConfigTypeErrorId = "config type error";

  `uvm_object_utils(sha256_env_config)

  axi4lite_agent_config axi4lite_agent_cfg;
  axis_agent_config     axis_agent_cfg;
  core_agent_config     core_agent_cfg;

  sha256_csr            csr_rb;
  intr_util             m_intr_util;
  rst_util              m_rst_util;

  bit                   has_scoreboard          = 1;
  bit                   has_functional_coverage = 1;
  bit                   enable_sb_check         = 1;

  extern function new(string name = "sha256_env_config");
  extern static function sha256_env_config get_config(uvm_component c);
  extern static function void set_config(uvm_component c, string inst_name, sha256_env_config cfg);
endclass : sha256_env_config

function sha256_env_config::new(string name = "sha256_env_config");
  super.new(name);
endfunction

function sha256_env_config sha256_env_config::get_config(uvm_component c);
  sha256_env_config t;

  if (!uvm_config_db#(sha256_env_config)::get(c, "", SMyConfigId, t)) begin
    `uvm_fatal("CONFIG_LOAD",
               $sformatf("Cannot get() configuration %s from uvm_config_db. Have you set() it?",
                         SMyConfigId))
  end
  return t;
endfunction

function void sha256_env_config::set_config(uvm_component c, string inst_name,
                                            sha256_env_config cfg);
  uvm_config_db#(sha256_env_config)::set(c, inst_name, SMyConfigId, cfg);
endfunction
