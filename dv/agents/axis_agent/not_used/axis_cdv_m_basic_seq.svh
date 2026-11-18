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
//   - Preserves the unused AXI4-Stream master CDV basic sequence for future verification extensions.
//------------------------------------------------------------------------------

class axis_cdv_m_basic_seq extends axis_base_seq;

  `uvm_object_utils(axis_cdv_m_basic_seq)

  rand int num_trans;

  constraint num_trans_c {num_trans inside {[500 : 1000]};}

  extern function new(string name = "axis_cdv_m_basic_seq");
  extern task body();

endclass : axis_cdv_m_basic_seq

function axis_cdv_m_basic_seq::new(string name = "axis_cdv_m_basic_seq");
  super.new(name);
endfunction

task axis_cdv_m_basic_seq::body();
  for (int i = 0; i < num_trans; i++) begin
    int pkt_len;
    req = new("req");
    configure_request(req);

    start_item(req);

    if (!std::randomize(
            pkt_len
        ) with {
          pkt_len dist {
            1 :/ 20,
            [2 : 15] :/ 50,
            [16 : 64] :/ 30
          };
        }) begin
      `uvm_fatal("SEQ_RAND", "pkt_len randomization failed")
    end

    if (!req.randomize() with {
          req.tdata_q.size() == local:: pkt_len;
          req.tid inside {[0 : 7]};
          req.tdest inside {[0 : 7]};
        }) begin
      `uvm_fatal("SEQ_RAND", "axis_seq_item randomization failed")
    end

    begin
      int tkeep_mode, tstrb_mode, tuser_mode;

      std::randomize(
          tkeep_mode
      ) with {
        tkeep_mode dist {
          0 :/ 15,
          1 :/ 15,
          2 :/ 70
        };
      };
      std::randomize(
          tstrb_mode
      ) with {
        tstrb_mode dist {
          0 :/ 15,
          1 :/ 15,
          2 :/ 70
        };
      };
      std::randomize(
          tuser_mode
      ) with {
        tuser_mode dist {
          0 :/ 15,
          1 :/ 15,
          2 :/ 70
        };
      };

      foreach (req.tdata_q[j]) begin
        if (tkeep_mode == 0) req.tkeep_q[j] = 0;
        else if (tkeep_mode == 1) req.tkeep_q[j] = '1;

        if (tstrb_mode == 0) req.tstrb_q[j] = 0;
        else if (tstrb_mode == 1) req.tstrb_q[j] = '1;

        req.tstrb_q[j] = req.tstrb_q[j] & req.tkeep_q[j];
        if (tuser_mode == 0) req.tuser_q[j] = 0;
        else if (tuser_mode == 1) req.tuser_q[j] = '1;
      end
    end

    foreach (req.valid_delay_q[j]) begin
      int delay_val;
      if (!std::randomize(
              delay_val
          ) with {
            delay_val dist {
              0 :/ 40,
              [1 : 5] :/ 30,
              [6 : 20] :/ 20,
              [21 : 100] :/ 10
            };
          }) begin
        `uvm_fatal("SEQ_RAND", "delay_val randomization failed")
      end
      if (j == 0 && pkt_len > 1 && $urandom_range(0, 9) < 3) begin
        delay_val = 0;
      end
      req.valid_delay_q[j] = delay_val;
    end

    finish_item(req);
  end
endtask
