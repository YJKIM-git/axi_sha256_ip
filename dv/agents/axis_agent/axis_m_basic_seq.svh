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
//   - Generates randomized AXI4-Stream master packets for basic SHA-256 data-path verification.
//------------------------------------------------------------------------------

class axis_m_basic_seq extends axis_base_seq;
  `uvm_object_utils(axis_m_basic_seq)

  rand int pkt_len;
  constraint pkt_len_c {soft pkt_len inside {[1 : 64]};}

  extern function new(string name = "axis_m_basic_seq");
  extern task body();
endclass : axis_m_basic_seq

function axis_m_basic_seq::new(string name = "axis_m_basic_seq");
  super.new(name);
endfunction

task axis_m_basic_seq::body();
  req = axis_seq_item::type_id::create("req");
  configure_request(req);

  start_item(req);

  if (!req.randomize() with {
        tdata_q.size() == local:: pkt_len;
        foreach (valid_delay_q[i]) {valid_delay_q[i] == 0;}
      }) begin
    `uvm_fatal("SEQ_RAND", "axis_m_basic_seq randomization failed")
  end

  finish_item(req);
endtask
