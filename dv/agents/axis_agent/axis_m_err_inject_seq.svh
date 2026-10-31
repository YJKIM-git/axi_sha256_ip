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
//   - Generates AXI4-Stream master error-injection packets for negative-path SHA-256 verification.
//------------------------------------------------------------------------------

class axis_m_err_inject_seq extends axis_base_seq;
  `uvm_object_utils(axis_m_err_inject_seq)

  rand int pkt_len;
  rand bit do_tlast_drop;
  rand bit do_tkeep_err;
  rand bit do_tvalid_drop;
  rand bit do_tid_change;

  constraint default_err_c {
    soft do_tlast_drop == 1'b0;
    soft do_tkeep_err == 1'b0;
    soft do_tvalid_drop == 1'b0;
    soft do_tid_change == 1'b0;
  }

  constraint pkt_len_c {soft pkt_len inside {[1 : 64]};}

  extern function new(string name = "axis_m_err_inject_seq");
  extern task body();

endclass : axis_m_err_inject_seq

function axis_m_err_inject_seq::new(string name = "axis_m_err_inject_seq");
  super.new(name);
endfunction

task axis_m_err_inject_seq::body();
  int num_bytes;
  int valid_bytes;

  req = axis_seq_item::type_id::create("req");

  configure_request(req);
  start_item(req);

  if (!req.randomize() with {
        tdata_q.size() == local:: pkt_len;
        tid inside {[0 : active_id_max]};
        tdest inside {[0 : active_dest_max]};

        drop_tlast == local:: do_tlast_drop;
        force_tkeep_error == local:: do_tkeep_err;
        force_tvalid_drop == local:: do_tvalid_drop;
        err_mid_pkt_tid_change == local:: do_tid_change;
      }) begin
    `uvm_fatal("SEQ_RAND", "axis_m_err_inject_seq randomization failed")
  end

  num_bytes = (req.active_data_width + 7) / 8;
  if (do_tkeep_err && (num_bytes > 1)) begin
    foreach (req.tkeep_q[i]) begin
      if (do_tlast_drop) begin
        valid_bytes    = $urandom_range(1, num_bytes - 1);
        req.tkeep_q[i] = (128'h1 << valid_bytes) - 1'b1;
      end else if ((req.tkeep_q[i] & (req.tkeep_q[i] + 1'b1)) == '0) begin
        req.tkeep_q[i][0]           = 1'b0;
        req.tkeep_q[i][num_bytes-1] = 1'b1;
      end
      req.tstrb_q[i] = req.tkeep_q[i];
    end
  end

  finish_item(req);
endtask
