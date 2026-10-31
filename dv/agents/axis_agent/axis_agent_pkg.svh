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
//   - Packages the AXI4-Stream agent components, sequence items, sequences, monitors, and coverage for SHA-256 verification.
//------------------------------------------------------------------------------

package axis_agent_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axis_seq_item.svh"
  `include "axis_agent_config.svh"
  `include "axis_m_driver.sv"
  // `include "axis_s_driver.sv"
  `include "axis_coverage.svh"
  `include "axis_monitor.sv"
  `include "axis_agent.svh"
  `include "axis_base_seq.svh"
  `include "axis_m_single_seq.svh"
  `include "axis_m_slow_seq.svh"
  `include "axis_m_stream_seq.svh"
  `include "axis_m_err_inject_seq.svh"
  `include "axis_m_basic_seq.svh"
  // `include "axis_m_b2b_seq.svh"
  // `include "axis_m_unaligned_seq.svh"
  // `include "axis_cdv_m_basic_seq.svh"
  // `include "axis_cdv_s_basic_seq.svh"
  // `include "axis_cdv_m_err_inject_seq.svh"
  // `include "axis_s_single_seq.svh"

  `include "axis_m_short_delay_seq.svh"

endpackage : axis_agent_pkg
