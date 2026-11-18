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
//   - Provides reset request and synchronization utilities for SHA-256 sequences.
//------------------------------------------------------------------------------

class rst_util extends uvm_object;
  `uvm_object_utils(rst_util)

  virtual rst_bfm m_bfm;
  event           reset_asserted;

  function new(string name = "rst_util");
    super.new(name);
  endfunction

  // [Usage: Sequence] Called by VSEQ to assert a synchronous-aligned hardware reset
  task assert_reset(int cycles = 20);
    m_bfm.drive_reset(cycles);
  endtask

  // [Usage: Sequence] Clock-cycle delay utility (eliminates #ns and direct clk_i probing in HVL)
  task wait_cycles(int cycles = 1);
    m_bfm.wait_cycles(cycles);
  endtask

  // [Usage: Sequence] Blocks until hardware reset is asserted
  task wait_for_reset_done();
    m_bfm.wait_for_reset_done();
  endtask

  // [Usage: Scoreboard] Blocks until hardware reset is asserted
  task wait_for_reset();
    @reset_asserted;
  endtask

  // [Internal] Triggered by rst_bfm when rst_n_o is asserted low
  function void notify_reset();
    ->reset_asserted;
  endfunction

  // [Internal] Called during test build_phase to link with BFM
  function void set_bfm(virtual rst_bfm bfm);
    m_bfm = bfm;
    m_bfm.proxy = this;
  endfunction



endclass : rst_util
