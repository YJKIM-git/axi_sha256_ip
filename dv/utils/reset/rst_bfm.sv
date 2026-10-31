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
//   - Implements the reset BFM used to drive and synchronize SHA-256 reset behavior.
//------------------------------------------------------------------------------

interface rst_bfm (
    input  logic clk_i,
    output logic rst_n_o
);

  import uvm_pkg::*;
  import rst_pkg::*;

  rst_util proxy;

  initial begin
    rst_n_o = 1'b0;
    repeat (20) @(posedge clk_i);
    rst_n_o = 1'b1;
  end

  initial begin
    forever begin
      if (proxy != null) begin
        @(proxy.reset_trigger);
        #1ns;

        `uvm_info("RST_BFM", $sformatf("Hardware Reset Asserted by VSEQ for %0d cycles",
                                       proxy.reset_cycles), UVM_HIGH)
        rst_n_o = 1'b0;
        repeat (proxy.reset_cycles) @(posedge clk_i);
        #1ns;
        rst_n_o = 1'b1;
        `uvm_info("RST_BFM", "Hardware Reset De-asserted", UVM_HIGH)
      end else begin
        @(posedge clk_i);
      end
    end
  end

endinterface : rst_bfm
