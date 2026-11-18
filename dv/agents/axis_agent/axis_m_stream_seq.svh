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
//   - Packs byte payloads into AXI4-Stream beats for SHA-256 message transmission.
//------------------------------------------------------------------------------

class axis_m_stream_seq extends axis_base_seq;

  `uvm_object_utils(axis_m_stream_seq)

  bit [7:0] payload_data[];

  extern function new(string name = "axis_m_stream_seq");
  extern task body();

endclass : axis_m_stream_seq

function axis_m_stream_seq::new(string name = "axis_m_stream_seq");
  super.new(name);
endfunction

task axis_m_stream_seq::body();
  int num_beats;
  int total_bytes;
  int bytes_per_beat;   // STRB variable

  total_bytes = payload_data.size();
  if (total_bytes == 0) `uvm_fatal("SEQ_ERR", "payload_data is empty")

  req = new("req");
  configure_request(req);

  bytes_per_beat = (req.active_data_width + 7) / 8;
  if (bytes_per_beat == 0) bytes_per_beat = 1;

  num_beats = (total_bytes + bytes_per_beat - 1) / bytes_per_beat;

  start_item(req);

  if (!req.randomize() with {
        req.tdata_q.size() == num_beats;
        req.tkeep_q.size() == num_beats;
        req.tstrb_q.size() == num_beats;
        req.valid_delay_q.size() == num_beats;
        req.tid inside {[0 : req.active_id_max]};
        req.tdest inside {[0 : req.active_dest_max]};
      })
    `uvm_fatal("SEQ_RAND", "axis_seq_item rand fail")

  for (int i = 0; i < num_beats; i++) begin
    logic [1023:0] beat_data = '0;
    logic [ 127:0] beat_keep = '0;

    for (int b = 0; b < bytes_per_beat; b++) begin
      int byte_idx = i * bytes_per_beat + b;
      if (byte_idx < total_bytes) begin
        beat_data[b*8+:8] = payload_data[byte_idx];
        beat_keep[b] = 1'b1;
      end
    end

    req.tdata_q[i] = beat_data;
    req.tkeep_q[i] = beat_keep;
    req.tstrb_q[i] = beat_keep;
    req.valid_delay_q[i] = 0;
  end

  finish_item(req);
endtask
