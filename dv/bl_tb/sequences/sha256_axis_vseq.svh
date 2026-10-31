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
//   - Combines AXI4-Stream master traffic with SHA-256 control-plane sequencing.
//------------------------------------------------------------------------------

class sha256_axis_vseq extends sha256_base_vseq;
  `uvm_object_utils(sha256_axis_vseq)

  extern function new(string name = "sha256_axis_vseq");
  extern virtual task body();
endclass : sha256_axis_vseq

function sha256_axis_vseq::new(string name = "sha256_axis_vseq");
  super.new(name);
endfunction

task sha256_axis_vseq::body();
  // 조립할 기본 시퀀스들 선언
  axis_m_single_seq      single_seq;
  axis_m_basic_seq       basic_seq;
  axis_m_stream_seq      stream_seq;
  axis_m_slow_seq        slow_seq;
  axis_m_short_delay_seq short_seq;

  super.body();
  `uvm_info("VSEQ_AXIS", "Starting Directed Sequence Combination...", UVM_LOW)

  fork
    begin : VIP_DATA_PLANE
      // [Test Plan: axis_pkt_boundary (Single), axis_handshake_delay (Zero)]
      repeat (10) begin
        single_seq = axis_m_single_seq::type_id::create("single_seq");
        if (!single_seq.randomize() with {pkt_len == 1;}) `uvm_fatal("VSEQ_AXIS", "rand fail")
        single_seq.start(axis_sqr);
      end

      // [Test Plan: axis_pkt_boundary (Burst)]
      repeat (10) begin
        basic_seq = axis_m_basic_seq::type_id::create("basic_seq");
        if (!basic_seq.randomize() with {pkt_len inside {[2 : 64]};})
          `uvm_fatal("VSEQ_AXIS", "rand fail")
        basic_seq.start(axis_sqr);
      end

      // [Test Plan: axis_tkeep (Partial), axis_data_pattern]
      stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
      stream_seq.payload_data = new[55];
      foreach (stream_seq.payload_data[i]) stream_seq.payload_data[i] = $urandom;
      stream_seq.start(axis_sqr);

      stream_seq = axis_m_stream_seq::type_id::create("stream_seq_toggle");
      stream_seq.payload_data = new[8];
      foreach (stream_seq.payload_data[i]) stream_seq.payload_data[i] = 8'h55;
      stream_seq.start(axis_sqr);

      // [Test Plan: axis_handshake_delay (Long/Backpressure)]
      slow_seq = axis_m_slow_seq::type_id::create("slow_seq");
      if (!slow_seq.randomize() with {
            num_trans == 10;
            pkt_len_min == 17;
            pkt_len_max == 64;
          })
        `uvm_fatal("VSEQ_AXIS", "slow_seq rand fail")
      slow_seq.start(axis_sqr);

      // [Test Plan: axis_handshake_delay (Short/Backpressure)]
      short_seq = axis_m_short_delay_seq::type_id::create("short_seq");
      if (!short_seq.randomize() with {
            num_trans == 9;
            pkt_len_min == 17;  // at least 1 block of 16 bytes
            pkt_len_max == 64;
            delay_min == 1;
            delay_max == 5;
          })
        `uvm_fatal("VSEQ_AXIS", "short_seq rand fail")
      short_seq.start(axis_sqr);

      `uvm_info("VSEQ_AXIS", "Data Plane All Phases Completed.", UVM_LOW)
    end

    // [Test Plan: oa_lifecycle]
    begin : CPU_CONTROL_PLANE
      forever begin
        csr_rb.CTRL.write(status, 32'h00000007);
        intr_proxy.wait_for_interrupt();
        csr_rb.INTCLEAR.write(status, 32'h00000002);
      end
    end
  join_any

  disable fork;

  `uvm_info("VSEQ_AXIS", "Completed Directed Sequence Combination", UVM_LOW)
endtask
