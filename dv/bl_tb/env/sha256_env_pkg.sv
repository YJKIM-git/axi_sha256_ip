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
//   - Packages the SHA-256 environment, scoreboard, coverage, and agent integration classes.
//------------------------------------------------------------------------------

// [gen] Initial block-level env package scaffold for SHA256 UVM bring-up.
package sha256_env_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import axi4lite_agent_pkg::*;
  import axis_agent_pkg::*;
  import core_agent_pkg::*;
  import intr_pkg::*;
  import rst_pkg::*;
  import sha256_reg_pkg::*;

  `include "sha256_env_config.svh"
  `include "sha256_scoreboard.svh"
  `include "sha256_csr_coverage.svh"
  `include "sha256_overall_coverage.svh"
  `include "sha256_env.svh"

endpackage : sha256_env_pkg
