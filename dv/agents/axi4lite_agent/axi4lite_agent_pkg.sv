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

//
// Class Description:
//
//
package axi4lite_agent_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axi4lite_seq_item.svh"
  `include "axi4lite_agent_config.svh"
  `include "axi4lite_driver.svh"
  `include "axi4lite_coverage_monitor.svh"
  `include "axi4lite_monitor.svh"

  typedef uvm_sequencer#(axi4lite_seq_item) axi4lite_sequencer;

  `include "axi4lite_agent.svh"
  `include "reg2axi4lite_adapter.svh"
  `include "axi4lite_seq.svh"
  `include "axi4lite_write_seq.svh"
  `include "axi4lite_err_inject_seq.svh"
  `include "axi4lite_protocol_cov_seq.svh"
  // `include "axi4lite_read_seq.svh"
  // `include "axi4lite_partial_write_seq.svh"
  // `include "axi4lite_sweep_seq.svh"

endpackage : axi4lite_agent_pkg
