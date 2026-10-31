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
//   - Provides interrupt wait and synchronization utilities for SHA-256 sequences.
//------------------------------------------------------------------------------

class intr_util extends uvm_object;
  `uvm_object_utils(intr_util)

  virtual intr_bfm m_bfm;

  bit intr_val = 0;
  event intr_asserted;
  event intr_deasserted;

  function new(string name = "intr_util");
    super.new(name);
  endfunction

  // [Usage: Sequence] Blocks execution until irq_o becomes 1.
  task wait_for_interrupt();
    if (intr_val == 0) @intr_asserted;
  endtask

  // [Usage: Sequence] Blocks execution until irq_o becomes 0.
  task wait_for_clear();
    if (intr_val == 1) @intr_deasserted;
  endtask

  // [Usage: Scoreboard/Coverage] Returns current irq_o state (0 or 1) without blocking.
  function bit get_irq_level();
    return intr_val;
  endfunction

  // [Internal] Triggered by BFM on irq_o rising edge.
  function void notify_interrupt();
    intr_val = 1;
    ->intr_asserted;
  endfunction

  // [Internal] Triggered by BFM on irq_o falling edge.
  function void notify_interrupt_cleared();
    intr_val = 0;
    ->intr_deasserted;
  endfunction

  // [Internal] Called during env connect_phase to link with BFM.
  function void set_bfm(virtual intr_bfm bfm);
    m_bfm = bfm;
    m_bfm.proxy = this;
  endfunction

endclass : intr_util
