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
//   - Preserves the unused AXI4-Stream master CDV error sequence for future negative testing.
//------------------------------------------------------------------------------

class axis_cdv_m_err_inject_seq extends axis_base_seq;

  `uvm_object_utils(axis_cdv_m_err_inject_seq)

  rand int pkt_len;

  constraint pkt_len_c {pkt_len inside {[100 : 200]};}

  extern function new(string name = "axis_cdv_m_err_inject_seq");
  extern task body();

endclass : axis_cdv_m_err_inject_seq

function axis_cdv_m_err_inject_seq::new(string name = "axis_cdv_m_err_inject_seq");
  super.new(name);
endfunction

task axis_cdv_m_err_inject_seq::body();
  req = new("req");
  configure_request(req);

  start_item(req);

  if (!req.randomize() with {
        req.tdata_q.size() == local:: pkt_len;
        req.tid inside {[0 : req.active_id_max]};
        req.tdest inside {[0 : req.active_dest_max]};
      }) begin
    `uvm_fatal("SEQ_RAND", "axis_seq_item randomization failed")
  end

  foreach (req.valid_delay_q[i]) begin
    req.valid_delay_q[i] = 0;
  end

  finish_item(req);
endtask
