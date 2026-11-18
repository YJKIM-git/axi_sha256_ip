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
//   - Packages the SHA-256 core verification agent, transaction types, monitor, and coverage components.
//------------------------------------------------------------------------------

package core_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "core_seq_item.svh"
  `include "core_agent_config.svh"
  `include "core_monitor.svh"
  `include "core_coverage.svh"
  `include "core_agent.svh"

endpackage : core_agent_pkg
