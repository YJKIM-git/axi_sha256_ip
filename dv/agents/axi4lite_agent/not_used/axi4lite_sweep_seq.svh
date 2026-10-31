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
class axi4lite_sweep_seq extends uvm_sequence #(axi4lite_seq_item);

  `uvm_object_utils(axi4lite_sweep_seq)

  rand logic [63:0] start_addr;
  rand logic [63:0] end_addr;
  rand int stride;

  constraint addr_c {
    start_addr < end_addr;
    stride inside {4, 8};
  }

  extern function new(string name = "axi4lite_sweep_seq");
  extern task body;

endclass : axi4lite_sweep_seq

function axi4lite_sweep_seq::new(string name = "axi4lite_sweep_seq");
  super.new(name);
endfunction

task axi4lite_sweep_seq::body;
  axi4lite_seq_item req;
  logic [63:0] current_addr;

  current_addr = start_addr;
  while (current_addr <= end_addr) begin
    req = axi4lite_seq_item::type_id::create("req");
    start_item(req);
    assert (req.randomize() with {
      dir == axi4lite_seq_item::WRITE;
      addr == current_addr;
    });
    finish_item(req);

    req = axi4lite_seq_item::type_id::create("req");
    start_item(req);
    assert (req.randomize() with {
      dir == axi4lite_seq_item::READ;
      addr == current_addr;
    });
    finish_item(req);

    current_addr += stride;
  end
endtask : body
