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

class axi4lite_err_inject_seq extends axi4lite_seq;

  `uvm_object_utils(axi4lite_err_inject_seq)

  rand int num_rand_err_trans;

  constraint num_rand_err_trans_c {num_rand_err_trans inside {[10 : 20]};}

  extern function new(string name = "axi4lite_err_inject_seq");
  extern task body();

endclass : axi4lite_err_inject_seq


function axi4lite_err_inject_seq::new(string name = "axi4lite_err_inject_seq");
  super.new(name);
endfunction

task axi4lite_err_inject_seq::body();
  axi4lite_seq_item req;
  req = axi4lite_seq_item::type_id::create("req");

  // 1. Unaligned Write
  start_item(req);
  if (!req.randomize() with {
        addr < 64'h1_0000_0000;
        dir == axi4lite_seq_item::WRITE;
        force_unaligned_addr == 1'b1;
        force_invalid_wstrb == 1'b0;
        ignore_ready_timeout == 1'b0;
      })
    `uvm_fatal("ERR_SEQ", "Randomization failed")
  if (req.addr[1:0] == 2'b00) req.addr[0] = 1'b1;
  finish_item(req);

  // 2. Unaligned Read
  start_item(req);
  if (!req.randomize() with {
        addr < 64'h1_0000_0000;
        dir == axi4lite_seq_item::READ;
        force_unaligned_addr == 1'b1;
        force_invalid_wstrb == 1'b0;
        ignore_ready_timeout == 1'b0;
      })
    `uvm_fatal("ERR_SEQ", "Randomization failed")
  if (req.addr[1:0] == 2'b00) req.addr[0] = 1'b1;
  finish_item(req);

  // 3. Write WSTRB All Zeros
  start_item(req);
  if (!req.randomize() with {
        addr < 64'h1_0000_0000;
        dir == axi4lite_seq_item::WRITE;
        force_unaligned_addr == 1'b0;
        force_invalid_wstrb == 1'b0;
        wstrb == 8'h00;
        ignore_ready_timeout == 1'b0;
      })
    `uvm_fatal("ERR_SEQ", "Randomization failed")
  req.addr[1:0] = 2'b00;
  finish_item(req);

  // 4. Write WSTRB Invalid
  start_item(req);
  if (!req.randomize() with {
        addr < 64'h1_0000_0000;
        dir == axi4lite_seq_item::READ;
        force_unaligned_addr == 1'b0;
        force_invalid_wstrb == 1'b0;
        wstrb == 8'h00;
        ignore_ready_timeout == 1'b0;
      })
    `uvm_fatal("ERR_SEQ", "Randomization failed")
  req.addr[1:0] = 2'b00;
  finish_item(req);

  // 5. Write WSTRB Invalid
  start_item(req);
  if (!req.randomize() with {
        addr < 64'h1_0000_0000;
        prot == 3'b000;
        force_unaligned_addr == 1'b0;
        force_invalid_wstrb == 1'b0;
        ignore_ready_timeout == 1'b0;
      })
    `uvm_fatal("ERR_SEQ", "Randomization failed")
  req.addr[1:0] = 2'b00;
  finish_item(req);

  // 6. Randomized Error Transactions
  for (int i = 0; i < num_rand_err_trans; i++) begin
    start_item(req);
    if (!req.randomize() with {
          addr < 64'h1_0000_0000;

          prot dist {
            3'b000 := 20,
            3'b001 := 20,
            3'b010 := 10,
            3'b011 := 10,
            3'b100 := 10,
            3'b101 := 10,
            3'b110 := 10,
            3'b111 := 10
          };

          force_unaligned_addr dist {
            0 := 70,
            1 := 30
          };
          force_invalid_wstrb dist {
            0 := 70,
            1 := 30
          };
          ignore_ready_timeout dist {
            0 := 90,
            1 := 10
          };
        })
      `uvm_fatal("ERR_SEQ", "Randomization failed")

    if (req.force_unaligned_addr == 1'b0) begin
      req.addr[1:0] = 2'b00;
    end else if (req.addr[1:0] == 2'b00) begin
      req.addr[0] = 1'b1;
    end

    finish_item(req);
  end
endtask : body
