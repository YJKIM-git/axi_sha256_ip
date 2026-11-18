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
//   - Generates AXI4-Stream master packets with short VALID delays for SHA-256 timing coverage.
//------------------------------------------------------------------------------

class axis_m_short_delay_seq extends axis_base_seq;

  `uvm_object_utils(axis_m_short_delay_seq)

  rand int num_trans;
  rand int pkt_len_min;
  rand int pkt_len_max;
  rand int delay_min;
  rand int delay_max;
  rand int zero_delay_prefix_beats;

  constraint num_trans_c {soft num_trans inside {[10 : 50]};}

  constraint pkt_len_limit_c {
    soft pkt_len_min >= 2;
    soft pkt_len_max <= 64;
    pkt_len_min <= pkt_len_max;
  }

  constraint delay_limit_c {
    soft delay_min == 1;
    soft delay_max == 5;
    delay_min <= delay_max;
  }

  constraint prefix_beats_c {soft zero_delay_prefix_beats == -1;}

  extern function new(string name = "axis_m_short_delay_seq");
  extern task body();

endclass : axis_m_short_delay_seq

function axis_m_short_delay_seq::new(string name = "axis_m_short_delay_seq");
  super.new(name);
endfunction

task axis_m_short_delay_seq::body();
  for (int i = 0; i < num_trans; i++) begin
    int pkt_len;
    int eff_prefix_beats;

    req = axis_seq_item::type_id::create("req");
    configure_request(req);

    start_item(req);

    if (zero_delay_prefix_beats < 0 && i == 0 && pkt_len_max >= 33) begin
      // Ensure at least one multi-block burst-prefix packet to saturate slave buffer
      int min_burst_len = (pkt_len_min > 33) ? pkt_len_min : 33;
      if (!std::randomize(pkt_len) with {pkt_len inside {[min_burst_len : pkt_len_max]};}) begin
        `uvm_fatal("SEQ_RAND", "pkt_len randomization failed")
      end
      eff_prefix_beats = 32;
    end else begin
      if (!std::randomize(pkt_len) with {pkt_len inside {[pkt_len_min : pkt_len_max]};}) begin
        `uvm_fatal("SEQ_RAND", "pkt_len randomization failed")
      end
      eff_prefix_beats = (zero_delay_prefix_beats > 0) ? zero_delay_prefix_beats : 0;
    end

    if (!req.randomize() with {
          tdata_q.size() == local:: pkt_len;
          tid inside {[0 : active_id_max]};
          tdest inside {[0 : active_dest_max]};
        }) begin
      `uvm_fatal("SEQ_RAND", "axis_seq_item randomization failed")
    end

    foreach (req.valid_delay_q[j]) begin
      if (j < eff_prefix_beats) begin
        req.valid_delay_q[j] = 0;
      end else begin
        int delay_val;
        if (!std::randomize(delay_val) with {delay_val inside {[delay_min : delay_max]};}) begin
          `uvm_fatal("SEQ_RAND", "delay_val randomization failed")
        end
        req.valid_delay_q[j] = delay_val;
      end
    end

    finish_item(req);
  end
endtask
