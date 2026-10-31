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
//   - Preserves the unused AXI4-Stream slave single-packet sequence for future back-pressure tests.
//------------------------------------------------------------------------------

class axis_s_single_seq extends axis_base_seq;

  `uvm_object_utils(axis_s_single_seq)

  rand int delay_length;

  constraint default_length_c {delay_length inside {[1 : 64]};}

  extern function new(string name = "axis_s_single_seq");
  extern task body();


endclass : axis_s_single_seq

function axis_s_single_seq::new(string name = "axis_s_single_seq");
  super.new(name);
endfunction

task axis_s_single_seq::body();
  req = new("req");
  configure_request(req);

  start_item(req);

  if (!req.randomize() with {req.ready_delay_q.size() == local:: delay_length;}) begin
    `uvm_fatal("SEQ_RAND", "axis_seq_item randomization failed")
  end

  finish_item(req);
endtask

