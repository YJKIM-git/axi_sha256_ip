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

  event reset_trigger;
  int reset_cycles;

  function new(string name = "rst_util");
    super.new(name);
  endfunction

  // [Usage: Sequence] Called by VSEQ and triggers a hard reset
  task assert_reset(int cycles = 20);
    reset_cycles = cycles;
    ->reset_trigger;

    @(posedge m_bfm.clk_i);
    while (m_bfm.rst_n_o == 1'b0) @(posedge m_bfm.clk_i);
  endtask

  // [Internal] Called during env connect_phase to link with BFM.
  function void set_bfm(virtual rst_bfm bfm);
    m_bfm = bfm;
    m_bfm.proxy = this;
  endfunction

endclass : rst_util
