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
class axi4lite_protocol_cov_seq extends axi4lite_seq;
  `uvm_object_utils(axi4lite_protocol_cov_seq)

  extern function new(string name = "axi4lite_protocol_cov_seq");
  extern task body();
endclass

function axi4lite_protocol_cov_seq::new(string name = "axi4lite_protocol_cov_seq");
  super.new(name);
endfunction

task axi4lite_protocol_cov_seq::body();
  axi4lite_seq_item req;

  req = axi4lite_seq_item::type_id::create("req");

  start_item(req);
  assert (req.randomize() with {
    dir == axi4lite_seq_item::READ;
    addr == 64'h0;
    ar_delay == 0;
    wstrb == 8'hFF;
  });
  finish_item(req);

  start_item(req);
  assert (req.randomize() with {
    dir == axi4lite_seq_item::WRITE;
    addr == 64'h4;
    aw_delay == 0;
    w_delay == 0;
  });
  finish_item(req);

  start_item(req);
  assert (req.randomize() with {
    dir == axi4lite_seq_item::WRITE;
    addr == 64'h8;
    aw_delay == 0;
    w_delay == 5;
  });
  finish_item(req);

  start_item(req);
  assert (req.randomize() with {
    dir == axi4lite_seq_item::WRITE;
    addr == 64'hC;
    aw_delay == 5;
    w_delay == 0;
  });
  finish_item(req);

  start_item(req);
  assert (req.randomize() with {
    dir == axi4lite_seq_item::WRITE;
    addr == 64'h10;
    aw_delay == 0;
    w_delay == 0;
  });
  finish_item(req);
endtask
