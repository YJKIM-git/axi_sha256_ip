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
//   - Preserves the unused AXI4-Stream master back-to-back sequence for future throughput testing.
//------------------------------------------------------------------------------

class axis_m_b2b_seq extends axis_base_seq;

  `uvm_object_utils(axis_m_b2b_seq)

  rand int num_trans;

  constraint num_trans_c {soft num_trans inside {[100 : 500]};}

  extern function new(string name = "axis_m_b2b_seq");
  extern task body();

endclass : axis_m_b2b_seq

function axis_m_b2b_seq::new(string name = "axis_m_b2b_seq");
  super.new(name);
endfunction

task axis_m_b2b_seq::body();
  for (int i = 0; i < num_trans; i++) begin
    int pkt_len;
    req = new("req");
    configure_request(req);

    start_item(req);

    if (!std::randomize(
            pkt_len
        ) with {
          pkt_len dist {
            1 :/ 10,
            [2 : 15] :/ 30,
            [16 : 64] :/ 60
          };
        }) begin
      `uvm_fatal("SEQ_RAND", "pkt_len randomization failed")
    end

    if (!req.randomize() with {
          req.tdata_q.size() == local:: pkt_len;
          req.tid inside {[0 : req.active_id_max]};
          req.tdest inside {[0 : req.active_dest_max]};
        }) begin
      `uvm_fatal("SEQ_RAND", "axis_seq_item randomization failed")
    end

    foreach (req.valid_delay_q[j]) begin
      req.valid_delay_q[j] = 0;
    end

    finish_item(req);
  end
endtask
