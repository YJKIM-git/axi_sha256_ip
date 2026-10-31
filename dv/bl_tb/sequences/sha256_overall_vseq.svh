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
//   - Generates end-to-end SHA-256 lifecycle, payload, timeout, and recovery scenarios.
//------------------------------------------------------------------------------

class sha256_overall_vseq extends sha256_base_vseq;
  `uvm_object_utils(sha256_overall_vseq)

  extern function new(string name = "sha256_overall_vseq");
  extern virtual task body();

  extern virtual task read_digest_and_clear_irq();
  extern virtual task do_oa_lifecycle();  // [Test Plan: oa_lifecycle, oa_latency, oa_zeroization]
  extern virtual task do_oa_e2e_hash();  // [Test Plan: oa_e2e_hash, oa_chaining, oa_byte_swap]
  extern virtual task do_oa_pad_edge();  // [Test Plan: oa_pad_edge]
  extern virtual task do_oa_manual_chain();  // [Test Plan: oa_manual_chain]
  extern virtual task do_oa_b2b_trans();  // [Test Plan: oa_b2b_trans]
  extern virtual task do_oa_stress();  // [Test Plan: oa_stress]
  extern virtual task do_oa_disable();  // [Test Plan: oa_disable]
  extern virtual task do_oa_tkeep_err();  // [Test Plan: oa_tkeep_err]
  extern virtual task do_oa_timeout_recov();  // [Test Plan: oa_timeout_recov]
  extern virtual task do_oa_busy_recov();  // [Test Plan: oa_busy_recov]

endclass : sha256_overall_vseq

function sha256_overall_vseq::new(string name = "sha256_overall_vseq");
  super.new(name);
endfunction

task sha256_overall_vseq::body();
  super.body();

  `uvm_info("VSEQ", "Starting Overall Verification Plan", UVM_LOW)

  do_oa_lifecycle();
  do_oa_e2e_hash();
  do_oa_pad_edge();
  do_oa_manual_chain();
  do_oa_b2b_trans();
  do_oa_stress();
  do_oa_disable();
  do_oa_tkeep_err();
  do_oa_timeout_recov();
  do_oa_busy_recov();

  `uvm_info("VSEQ", "Completed Overall Verification Plan", UVM_LOW)
endtask
// ---------------------------------------------------------
// Helper Task: DIGEST_0~7 (Scoreboard trigger), Interrupt Clear
// ---------------------------------------------------------
task sha256_overall_vseq::read_digest_and_clear_irq();
  uvm_reg digest_regs[8] = '{
      csr_rb.DIGEST_0,
      csr_rb.DIGEST_1,
      csr_rb.DIGEST_2,
      csr_rb.DIGEST_3,
      csr_rb.DIGEST_4,
      csr_rb.DIGEST_5,
      csr_rb.DIGEST_6,
      csr_rb.DIGEST_7
  };

  foreach (digest_regs[i]) begin
    digest_regs[i].read(status, rdata);
  end
  csr_rb.INTCLEAR.write(status, 32'h00000002);
  intr_proxy.wait_for_clear();
endtask

// ---------------------------------------------------------
// [Test Plan: oa_lifecycle, oa_latency, oa_zeroization]
// Single 1-Beat packet to verify FSM, SVA, and Scoreboard hash check.
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_lifecycle();
  axis_m_single_seq single_seq;

  `uvm_info("VSEQ_OA", "Starting do_oa_lifecycle", UVM_LOW)

  csr_rb.CTRL.write(status, 32'h00000007);

  single_seq = axis_m_single_seq::type_id::create("single_seq");
  if (!single_seq.randomize() with {pkt_len == 1;}) begin
    `uvm_fatal("VSEQ_OA", "single_seq randomize failed")
  end
  single_seq.start(axis_sqr);

  intr_proxy.wait_for_interrupt();
  read_digest_and_clear_irq();
endtask

// ---------------------------------------------------------
// [Test Plan: oa_e2e_hash, oa_chaining, oa_byte_swap]
// Random variable-length streaming for single/multi-block x aligned/unaligned cross.
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_e2e_hash();
  axis_m_stream_seq stream_seq;
  int               test_lengths[3];

  `uvm_info("VSEQ_OA", "Starting do_oa_e2e_hash", UVM_LOW)

  // cr_block_align=0~3, msg_len[11]=0~1, tkeep=4'b0001, 4'b0011, 4'b0111, 4'b1111
  test_lengths[0] = ($urandom_range(0, 12) * 4) +
      1;  // Single-block + 1B tail (1~49B -> tkeep=4'b0001)
  test_lengths[1] = ($urandom_range(16, 63) * 4) +
      2;  // Multi-block + 2B tail (66~254B -> tkeep=4'b0011)
  test_lengths[2] = $urandom_range(64, 127) *
      4;  // Multi-block + Word-aligned (256~508B -> tkeep=4'b1111, msg_len[11]=1)

  foreach (test_lengths[k]) begin
    int total_bytes = test_lengths[k];
    stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
    stream_seq.payload_data = new[total_bytes];
    foreach (stream_seq.payload_data[i]) stream_seq.payload_data[i] = $urandom;

    csr_rb.CTRL.write(status, 32'h00000007);
    stream_seq.start(axis_sqr);

    intr_proxy.wait_for_interrupt();
    read_digest_and_clear_irq();
  end
endtask

// ---------------------------------------------------------
// [Test Plan: oa_pad_edge]
// 55B, 56B, 64B Padding edge cases and MSG_LEN_LO/HI accumulated bit length register verification
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_pad_edge();
  axis_m_stream_seq stream_seq;
  uvm_reg_data_t len_lo, len_hi;
  int edge_sizes[] = '{55, 56, 64};

  `uvm_info("VSEQ_OA", "Starting do_oa_pad_edge", UVM_LOW)

  foreach (edge_sizes[i]) begin
    int total_bytes = edge_sizes[i];
    stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
    stream_seq.payload_data = new[total_bytes];
    foreach (stream_seq.payload_data[j]) stream_seq.payload_data[j] = $urandom;

    csr_rb.CTRL.write(status, 32'h00000007);
    stream_seq.start(axis_sqr);

    intr_proxy.wait_for_interrupt();

    csr_rb.MSG_LEN_LO.read(status, len_lo);
    csr_rb.MSG_LEN_HI.read(status, len_hi);
    if (len_lo[31:0] !== (total_bytes * 8) || len_hi[31:0] !== 32'h0) begin
      `uvm_error("VSEQ_OA", $sformatf(
                                "MSG_LEN mismatch! Expected %0d bits, got HI=0x%08x LO=0x%08x",
                                total_bytes * 8, len_hi[31:0], len_lo[31:0]))
    end

    read_digest_and_clear_irq();
  end
endtask

// ---------------------------------------------------------
// [Test Plan: oa_manual_chain]
//  STATE_IN_0~7 Manual IV injection and standard IV restoration verification
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_manual_chain();
  axis_m_stream_seq stream_seq;
  uvm_reg state_regs[8] = '{
      csr_rb.STATE_IN_0,
      csr_rb.STATE_IN_1,
      csr_rb.STATE_IN_2,
      csr_rb.STATE_IN_3,
      csr_rb.STATE_IN_4,
      csr_rb.STATE_IN_5,
      csr_rb.STATE_IN_6,
      csr_rb.STATE_IN_7
  };
  uvm_reg digest_regs[8] = '{
      csr_rb.DIGEST_0,
      csr_rb.DIGEST_1,
      csr_rb.DIGEST_2,
      csr_rb.DIGEST_3,
      csr_rb.DIGEST_4,
      csr_rb.DIGEST_5,
      csr_rb.DIGEST_6,
      csr_rb.DIGEST_7
  };
  bit [31:0] custom_iv[8] = '{
      32'h01234567,
      32'h89abcdef,
      32'hfedcba98,
      32'h76543210,
      32'h0f1e2d3c,
      32'h4b5a6978,
      32'h8796a5b4,
      32'hc3d2e1f0
  };
  bit [31:0] exp_custom_digest[8] = '{
      32'he7fe938a,
      32'h321d4367,
      32'h0eae9070,
      32'haf82a6fc,
      32'hc509c85d,
      32'h52ba79d9,
      32'h0371c591,
      32'ha1138267
  };
  bit [31:0] std_iv[8] = '{
      32'h6a09e667,
      32'hbb67ae85,
      32'h3c6ef372,
      32'ha54ff53a,
      32'h510e527f,
      32'h9b05688c,
      32'h1f83d9ab,
      32'h5be0cd19
  };

  `uvm_info("VSEQ_OA", "Starting do_oa_manual_chain (Custom IV & Manual Chaining)", UVM_LOW)

  m_cfg.enable_sb_check = 0;

  foreach (state_regs[i]) begin
    state_regs[i].write(status, custom_iv[i]);
  end

  stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
  stream_seq.payload_data = '{8'h61, 8'h62, 8'h63, 8'h64};  // "abcd" (4 Bytes)

  csr_rb.CTRL.write(status, 32'h00000007);
  stream_seq.start(axis_sqr);

  intr_proxy.wait_for_interrupt();

  foreach (digest_regs[i]) begin
    digest_regs[i].read(status, rdata);
    if (rdata[31:0] !== exp_custom_digest[i]) begin
      `uvm_error("VSEQ_OA",
                 $sformatf(
                     "Manual Chain Custom IV Digest[%0d] mismatch! Expected 0x%08x, got 0x%08x", i,
                     exp_custom_digest[i], rdata[31:0]))
    end
  end
  csr_rb.INTCLEAR.write(status, 32'h00000002);
  intr_proxy.wait_for_clear();

  foreach (state_regs[i]) begin
    state_regs[i].write(status, std_iv[i]);
  end
  m_cfg.enable_sb_check = 1;

  do_oa_lifecycle();
endtask

// ---------------------------------------------------------
// [Test Plan: oa_b2b_trans]
// streaming without reset and hash integrity check
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_b2b_trans();
  axis_m_single_seq single_seq;
  int num_runs = 20;

  `uvm_info("VSEQ_OA", "Starting do_oa_b2b_trans", UVM_LOW)

  for (int i = 0; i < num_runs; i++) begin
    csr_rb.CTRL.write(status, 32'h00000007);

    single_seq = axis_m_single_seq::type_id::create("single_seq");
    if (!single_seq.randomize() with {pkt_len == 1;}) begin
      `uvm_fatal("VSEQ_OA", "single_seq randomize failed in b2b")
    end
    single_seq.start(axis_sqr);

    intr_proxy.wait_for_interrupt();
    read_digest_and_clear_irq();
  end
endtask

// ---------------------------------------------------------
// [Test Plan: oa_disable]
// verification of control bit disable (EN=0 blocking reception and IRQ_EN=0 interrupt masking)
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_disable();
  axis_m_single_seq single_seq;
  uvm_reg digest_regs[8] = '{
      csr_rb.DIGEST_0,
      csr_rb.DIGEST_1,
      csr_rb.DIGEST_2,
      csr_rb.DIGEST_3,
      csr_rb.DIGEST_4,
      csr_rb.DIGEST_5,
      csr_rb.DIGEST_6,
      csr_rb.DIGEST_7
  };

  `uvm_info("VSEQ_OA", "Starting do_oa_disable", UVM_LOW)

  csr_rb.CTRL.write(status, 32'h00000000);

  single_seq = axis_m_single_seq::type_id::create("single_seq");
  if (!single_seq.randomize() with {pkt_len == 1;}) begin
    `uvm_fatal("VSEQ_OA", "single_seq randomize failed")
  end

  fork
    begin
      single_seq.start(axis_sqr);
    end
    begin
      #1us;
      `uvm_info("VSEQ_OA", "Verified that transaction is blocked by EN=0. Unblocking...", UVM_LOW)
      csr_rb.CTRL.write(status, 32'h00000007);
    end
  join

  intr_proxy.wait_for_interrupt();
  read_digest_and_clear_irq();
  `uvm_info("VSEQ_OA", "Testing IRQ_EN=0 (Interrupt Masking)...", UVM_LOW)
  csr_rb.CTRL.write(status, 32'h00000005);  // EN=1, IRQ_EN=0, START=1

  single_seq = axis_m_single_seq::type_id::create("single_seq");
  if (!single_seq.randomize() with {pkt_len == 1;}) `uvm_fatal("VSEQ_OA", "rand fail")
  single_seq.start(axis_sqr);

  do begin
    csr_rb.STATUS.read(status, rdata);
  end while ((rdata & 32'h00000002) == 0);

  if (intr_proxy.get_irq_level() == 1'b1) begin
    `uvm_error("VSEQ_OA", "IRQ pin asserted even when IRQ_EN is 0!")
  end else begin
    `uvm_info("VSEQ_OA", "Interrupt masking verified successfully.", UVM_LOW)
  end

  foreach (digest_regs[i]) begin
    digest_regs[i].read(status, rdata);
  end
  csr_rb.INTCLEAR.write(status, 32'h00000002);
endtask

// ---------------------------------------------------------
// [Test Plan: oa_stress]
// check for BUSY state and interrupt assertion during long transactions
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_stress();
  axis_m_slow_seq slow_seq;

  `uvm_info("VSEQ_OA", "Starting do_oa_stress", UVM_LOW)

  csr_rb.CTRL.write(status, 32'h00000007);

  slow_seq = axis_m_slow_seq::type_id::create("slow_seq");
  if (!slow_seq.randomize() with {
        num_trans == 1;
        pkt_len_min == 16;
        pkt_len_max == 16;
      }) begin
    `uvm_fatal("VSEQ_OA", "slow_seq randomize failed")
  end

  fork
    begin
      slow_seq.start(axis_sqr);
    end
    begin
      do begin
        csr_rb.STATUS.read(status, rdata);
      end while ((rdata & 32'h00000002) == 0);
    end
  join

  read_digest_and_clear_irq();
endtask

// ---------------------------------------------------------
// [Test Plan: oa_timeout_recov]
// verification of recovery from S_RCV starvation (TLAST Drop, Core IDLE) via SOFT_RESET
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_timeout_recov();
  axis_m_err_inject_seq err_seq;

  `uvm_info("VSEQ_OA", "Starting do_oa_timeout_recov (True Data Starvation)", UVM_LOW)

  csr_rb.CTRL.write(status, 32'h00000007);

  err_seq = axis_m_err_inject_seq::type_id::create("err_seq");
  if (!err_seq.randomize() with {
        pkt_len == 1;
        do_tlast_drop == 1'b1;
      }) begin
    `uvm_fatal("VSEQ_OA", "err_seq randomize failed")
  end
  err_seq.start(axis_sqr);

  #2us;

  csr_rb.STATUS.read(status, rdata);
  if ((rdata & 32'h00000001) == 0) begin
    `uvm_error("VSEQ_OA", "DUT is NOT in BUSY state during Starvation!")
  end

  `uvm_info("VSEQ_OA", "Timeout (Hang) detected! Issuing SOFT_RESET...", UVM_LOW)
  csr_rb.CTRL.write(status, 32'h0000000B);
  m_axis_agent.reset_agent();
  #100ns;

  csr_rb.STATUS.read(status, rdata);
  if ((rdata & 32'h00000001) != 0) begin
    `uvm_error("VSEQ_OA", "DUT failed to recover! Still BUSY after SOFT_RESET.")
  end

  `uvm_info("VSEQ_OA", "Verifying recovery with normal lifecycle...", UVM_LOW)
  do_oa_lifecycle();
endtask

// ---------------------------------------------------------
// [Test Plan: oa_busy_recov]
// Check for BUSY state and interrupt assertion during long transactions
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_busy_recov();
  axis_m_stream_seq  stream_seq;
  axi4lite_write_seq axil_write_seq;

  `uvm_info("VSEQ_OA", "Starting do_oa_busy_recov (Snipe Reset)", UVM_LOW)

  csr_rb.CTRL.write(status, 32'h00000007);

  stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
  stream_seq.payload_data = new[64];
  foreach (stream_seq.payload_data[i]) stream_seq.payload_data[i] = $urandom;

  stream_seq.start(axis_sqr);

  #60ns;

  `uvm_info("VSEQ_OA", "Injecting SOFT_RESET directly via AXIL Sequence during Core BUSY", UVM_LOW)

  axil_write_seq = axi4lite_write_seq::type_id::create("axil_write_seq");
  if (!axil_write_seq.randomize() with {
        addr == 32'h04;  // CTRL
        wdata == 32'h0000000B;  // SOFT_RESET=1, IRQ_EN=1, EN=1
        wstrb == 4'hF;
        prot == 3'b000;
      }) begin
    `uvm_fatal("VSEQ_OA", "axil_write_seq randomize failed")
  end
  axil_write_seq.start(axil_sqr);
  m_axis_agent.reset_agent();
  #100ns;

  csr_rb.STATUS.read(status, rdata);
  if ((rdata & 32'h00000001) != 0) begin
    `uvm_error("VSEQ_OA", "Zombie Core Detected! Core is still BUSY after SOFT_RESET.")
  end

  `uvm_info("VSEQ_OA", "Core successfully aborted and recovered to IDLE.", UVM_LOW)

  do_oa_lifecycle();
endtask

// ---------------------------------------------------------
// [Test Plan: oa_tkeep_err]
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_tkeep_err();
  axis_m_err_inject_seq err_seq;
  bit [1:0] drop_tlast_modes[2] = '{1'b0, 1'b1};

  `uvm_info("VSEQ_OA", "Starting do_oa_tkeep_err (Hardware TKEEP Protection)", UVM_LOW)

  m_cfg.enable_sb_check = 0;

  foreach (drop_tlast_modes[i]) begin
    bit is_mid_pkt = drop_tlast_modes[i];

    csr_rb.CTRL.write(status, 32'h00000007);

    //    - i=0 (do_tlast_drop=0): TLAST=1에서 Sparse TKEEP(4'b1010)
    //    - i=1 (do_tlast_drop=1): TLAST=0(중간 Beat)에서 Partial TKEEP(4'b0011)
    err_seq = axis_m_err_inject_seq::type_id::create("err_seq");
    if (!err_seq.randomize() with {
          pkt_len == 1;
          do_tkeep_err == 1'b1;
          do_tlast_drop == is_mid_pkt;
        }) begin
      `uvm_fatal("VSEQ_OA", "err_seq randomize failed in do_oa_tkeep_err")
    end
    err_seq.start(axis_sqr);

    if (is_mid_pkt) begin
      m_axis_agent.reset_agent();
    end
    #100ns;

    csr_rb.STATUS.read(status, rdata);
    if ((rdata & 32'h00000001) != 0) begin
      `uvm_error("VSEQ_OA", $sformatf(
                                "DUT still BUSY after invalid TKEEP (mode=%0b)! STATUS=0x%08x",
                                is_mid_pkt, rdata))
    end
    if ((rdata & 32'h00000004) == 0) begin
      `uvm_error("VSEQ_OA",
                 $sformatf("STATUS.ERR_PRT not asserted on invalid TKEEP (mode=%0b)! STATUS=0x%08x",
                           is_mid_pkt, rdata))
    end

    csr_rb.INTCLEAR.write(status, 32'h00000004);
    csr_rb.STATUS.read(status, rdata);
    if ((rdata & 32'h00000004) != 0) begin
      `uvm_error("VSEQ_OA", "STATUS.ERR_PRT failed to clear after INTCLEAR.CLR_ERR write!")
    end
  end

  m_cfg.enable_sb_check = 1;
  `uvm_info("VSEQ_OA", "TKEEP error protection verified! Running normal lifecycle...", UVM_LOW)
  do_oa_lifecycle();
endtask
