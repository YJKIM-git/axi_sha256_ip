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
//   - Generates AXI4-Stream master packets with long VALID delays for SHA-256 stress testing.
//------------------------------------------------------------------------------

class axis_m_slow_seq extends axis_base_seq;

  `uvm_object_utils(axis_m_slow_seq)

  rand int num_trans;

  rand int pkt_len_min;
  rand int pkt_len_max;

  constraint num_trans_c {soft num_trans inside {[50 : 200]};}

  constraint pkt_len_limit_c {
    soft pkt_len_min >= 2;
    soft pkt_len_max <= 16;
    pkt_len_min <= pkt_len_max;
  }

  extern function new(string name = "axis_m_slow_seq");
  extern task body();

endclass : axis_m_slow_seq

function axis_m_slow_seq::new(string name = "axis_m_slow_seq");
  super.new(name);
endfunction

task axis_m_slow_seq::body();
  for (int i = 0; i < num_trans; i++) begin
    int pkt_len;
    req = new("req");
    configure_request(req);

    start_item(req);

    pkt_len = $urandom_range(pkt_len_max, pkt_len_min);

    if (!req.randomize() with {
          req.tdata_q.size() == local:: pkt_len;
          req.tid inside {[0 : req.active_id_max]};
          req.tdest inside {[0 : req.active_dest_max]};
        }) begin
      `uvm_fatal("SEQ_RAND", "axis_seq_item randomization failed")
    end

    foreach (req.valid_delay_q[j]) begin
      int delay_val;
      if (!std::randomize(
              delay_val
          ) with {
            delay_val dist {
              [10 :  30] :/ 50,
              [31 : 100] :/ 50
            };
          }) begin
        `uvm_fatal("SEQ_RAND", "delay_val randomization failed")
      end
      req.valid_delay_q[j] = delay_val;
    end

    finish_item(req);
  end
endtask
