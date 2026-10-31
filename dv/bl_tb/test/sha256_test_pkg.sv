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
//   - Packages all SHA-256 block-level UVM tests.
//------------------------------------------------------------------------------

// [gen] Initial test library scaffold for SHA256 block-level bring-up.
package sha256_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import axi4lite_agent_pkg::*;
  import axis_agent_pkg::*;
  import core_agent_pkg::*;
  import intr_pkg::*;
  import rst_pkg::*;
  import sha256_env_pkg::*;
  import sha256_vseq_pkg::*;

  `include "sha256_test_base.svh"
  `include "sha256_sanity_test.svh"
  `include "sha256_csr_test.svh"
  `include "sha256_overall_test.svh"
  `include "sha256_core_test.svh"
  `include "sha256_axil_test.svh"
  `include "sha256_axis_test.svh"

endpackage : sha256_test_pkg
