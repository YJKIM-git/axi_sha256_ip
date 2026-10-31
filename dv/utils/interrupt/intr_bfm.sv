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
//   - Implements the interrupt BFM used to synchronize SHA-256 completion events.
//------------------------------------------------------------------------------

interface intr_bfm (
    input logic clk_i,
    input logic rst_n_i,
    input logic irq_o
);

  import uvm_pkg::*;
  import intr_pkg::*;

  intr_util proxy;

  initial begin
    forever begin
      @(posedge clk_i);

      if (proxy != null && rst_n_i) begin
        if (irq_o === 1'b1 && proxy.get_irq_level() == 1'b0) begin
          proxy.notify_interrupt();
        end else if (irq_o === 1'b0 && proxy.get_irq_level() == 1'b1) begin
          proxy.notify_interrupt_cleared();
        end
      end
    end
  end

  // =========================================================
  // SVA: test_plan_csr/csr_reset(intr)
  // =========================================================
  property p_rst_irq;
    @(posedge clk_i) !rst_n_i |-> (irq_o == 1'b0);
  endproperty
  assert property (p_rst_irq);

endinterface : intr_bfm
