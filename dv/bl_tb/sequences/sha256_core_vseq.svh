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
//   - Generates SHA-256 core data-pattern and reset-recovery virtual-sequence stimulus.
//------------------------------------------------------------------------------

class sha256_core_vseq extends sha256_base_vseq;
  `uvm_object_utils(sha256_core_vseq)

  extern function new(string name = "sha256_core_vseq");
  extern virtual task body();

  extern virtual task do_core_dp_stress();    // [Test Plan: dp_stress, io_handshake, ctrl_fsm]
  extern virtual task do_core_rst_recovery(); // [Test Plan: rst_recovery]

  extern virtual task inject_pattern(bit [7:0] pattern[]);

endclass : sha256_core_vseq

function sha256_core_vseq::new(string name = "sha256_core_vseq");
  super.new(name);
endfunction

task sha256_core_vseq::body();
  super.body();

  `uvm_info("VSEQ_CORE", "Starting Core Verification Plan (Anti-pattern Free)", UVM_LOW)

  do_core_dp_stress();
  do_core_rst_recovery();

  `uvm_info("VSEQ_CORE", "Completed Core Verification Plan", UVM_LOW)
endtask

task sha256_core_vseq::inject_pattern(bit [7:0] pattern[]);
  axis_m_stream_seq stream_seq;
  uvm_reg           digest_regs[8];

  csr_rb.CTRL.write(status, 32'h00000007);

  stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
  stream_seq.payload_data = new[pattern.size()];
  foreach (pattern[i]) stream_seq.payload_data[i] = pattern[i];

  stream_seq.start(axis_sqr);

  intr_proxy.wait_for_interrupt();

  digest_regs = '{csr_rb.DIGEST_0, csr_rb.DIGEST_1, csr_rb.DIGEST_2, csr_rb.DIGEST_3,
                  csr_rb.DIGEST_4, csr_rb.DIGEST_5, csr_rb.DIGEST_6, csr_rb.DIGEST_7};
  foreach (digest_regs[i]) begin
    digest_regs[i].read(status, rdata);
  end
  csr_rb.INTCLEAR.write(status, 32'h00000002);
  intr_proxy.wait_for_clear();
endtask

task sha256_core_vseq::do_core_dp_stress();
  bit [7:0] payload[];

  `uvm_info("VSEQ_CORE", "Starting do_core_dp_stress", UVM_LOW)
  payload = new[64];

  // 1. All-Zero Pattern
  `uvm_info("VSEQ_CORE", "Injecting All-Zero Pattern", UVM_LOW)
  foreach (payload[i]) payload[i] = 8'h00;
  inject_pattern(payload);

  // 2. All-One Pattern
  `uvm_info("VSEQ_CORE", "Injecting All-One Pattern", UVM_LOW)
  foreach (payload[i]) payload[i] = 8'hFF;
  inject_pattern(payload);

  // 3. Walking-One Pattern (only one bit set to 1 in the entire 512-bit payload)
  `uvm_info("VSEQ_CORE", "Injecting Walking-One Pattern", UVM_LOW)
  foreach (payload[i]) payload[i] = 8'h00;
  payload[15] = 8'h08;
  inject_pattern(payload);

  // 4. Walking-Zero Pattern (only one bit set to 0 in the entire 512-bit payload)
  `uvm_info("VSEQ_CORE", "Injecting Walking-Zero Pattern", UVM_LOW)
  foreach (payload[i]) payload[i] = 8'hFF;
  payload[33] = ~(8'h04);
  inject_pattern(payload);
endtask

task sha256_core_vseq::do_core_rst_recovery();
  bit [7:0] payload[] = new[16];
  int uvm_skew        = 3;    //S_PAD_80(1) + S_PAD_LEN(1) + S_START_CORE(1)
  axis_m_stream_seq stream_seq;

  `uvm_info("VSEQ_CORE", "Starting do_core_rst_recovery (Sequential Safe Mode)", UVM_LOW)

  for (int delay = uvm_skew; delay <= uvm_skew + 68; delay++) begin
    foreach (payload[i]) payload[i] = $urandom;

    csr_rb.CTRL.write(status, 32'h00000007);

    stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
    stream_seq.payload_data = new[16];
    foreach (payload[i]) stream_seq.payload_data[i] = payload[i];
    stream_seq.start(axis_sqr);
    repeat (delay) @(posedge m_cfg.core_agent_cfg.mon_bfm.clk_i);
    `uvm_info("VSEQ_CORE", $sformatf("Asserting Hardware Reset at delay %0d", delay), UVM_HIGH)
    m_cfg.m_rst_util.assert_reset(20);

    #200ns;
  end

  foreach (payload[i]) payload[i] = $urandom;
  inject_pattern(payload);
endtask
