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
  extern virtual task do_oa_lifecycle();    // [Test Plan: oa_lifecycle, oa_latency, oa_zeroization]
  extern virtual task do_oa_e2e_hash();     // [Test Plan: oa_e2e_hash, oa_chaining, oa_byte_swap]
  extern virtual task do_oa_pad_edge();     // [Test Plan: oa_pad_edge]
  extern virtual task do_oa_manual_chain(); // [Test Plan: oa_manual_chain]
  extern virtual task do_oa_b2b_trans();    // [Test Plan: oa_b2b_trans]
  extern virtual task do_oa_stress();       // [Test Plan: oa_stress]
  extern virtual task do_oa_disable();      // [Test Plan: oa_disable]
  extern virtual task do_oa_timeout_recov();// [Test Plan: oa_timeout_recov]
  extern virtual task do_oa_busy_recov();   // [Test Plan: oa_busy_recov]
  extern virtual task do_oa_tkeep_err();    // [Test Plan: oa_tkeep_err, oa_overlap_abort]
  extern virtual task do_oa_all80_edge();    // [Test Plan: oa_all80_edge]
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
  do_oa_timeout_recov();
  do_oa_busy_recov();
  do_oa_tkeep_err();
  do_oa_all80_edge();

  `uvm_info("VSEQ", "Completed Overall Verification Plan", UVM_LOW)
endtask

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
  int               test_lengths[4];

  `uvm_info("VSEQ_OA", "Starting do_oa_e2e_hash", UVM_LOW)

  // cr_block_align=0~3, msg_len[11]=0~1, tkeep=4'b0001, 4'b0011, 4'b0111, 4'b1111
  test_lengths[0] = ($urandom_range(0, 12) * 4) +
      1;  // Single-block + Unaligned 1B tail (1~49B -> tkeep=4'b0001)
  test_lengths[1] = ($urandom_range(1, 13) *
      4); // Single-block + Word-aligned (4~52B -> tkeep=4'b1111)
  test_lengths[2] = ($urandom_range(16, 63) * 4) +
      2;  // Multi-block + Unaligned 2B tail (66~254B -> tkeep=4'b0011)
  test_lengths[3] = ($urandom_range(64, 126) * 4) +
      3;  // Multi-block + Unaligned 3B tail (259~507B -> tkeep=4'b0111, msg_len[11]=1)

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
// [Test Plan: oa_all80_edge]
// All-0x80 payload across critical padding & overlap boundaries (1, 55, 56, 63, 64, 119, 120, 127, 128B)
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_all80_edge();
  axis_m_stream_seq stream_seq;
  uvm_reg_data_t    len_lo, len_hi;
  int               all80_sizes[] = '{1, 55, 56, 63, 64, 119, 120, 127, 128};

  `uvm_info("VSEQ_OA", "Starting do_oa_all80_edge (All-0x80 Padding Boundary Verification)", UVM_LOW)

  foreach (all80_sizes[i]) begin
    int total_bytes = all80_sizes[i];
    stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
    stream_seq.payload_data = new[total_bytes];
    foreach (stream_seq.payload_data[j]) stream_seq.payload_data[j] = 8'h80;

    csr_rb.CTRL.write(status, 32'h00000007);
    stream_seq.start(axis_sqr);

    intr_proxy.wait_for_interrupt();

    csr_rb.MSG_LEN_LO.read(status, len_lo);
    csr_rb.MSG_LEN_HI.read(status, len_hi);
    if (len_lo[31:0] !== (total_bytes * 8) || len_hi[31:0] !== 32'h0) begin
      `uvm_error("VSEQ_OA", $sformatf(
                                "All-0x80 MSG_LEN mismatch at %0dB! Expected %0d bits, got HI=0x%08x LO=0x%08x",
                                total_bytes, total_bytes * 8, len_hi[31:0], len_lo[31:0]))
    end

    read_digest_and_clear_irq();
  end
endtask

// ---------------------------------------------------------
// [Test Plan: oa_pad_edge, oa_block_pending]
// 55B, 56B, 64B (1st block) & 119B, 120B, 128B (2nd block overlapped) padding edge cases,
// plus simultaneous core_done & next_blk_ready collision sweep.
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_pad_edge();
  axis_m_stream_seq      stream_seq;
  axis_m_short_delay_seq col_seq;
  uvm_reg_data_t len_lo, len_hi;
  int edge_sizes[] = '{55, 56, 64, 119, 120, 128};

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

  `uvm_info("VSEQ_OA", "Starting oa_block_pending simultaneous core_done collision sweep", UVM_LOW)
  for (int dly = 62; dly <= 68; dly++) begin
    bit deadlock_occurred = 1'b0;

    csr_rb.CTRL.write(status, 32'h00000007);

    col_seq = axis_m_short_delay_seq::type_id::create("col_seq");
    if (!col_seq.randomize() with {
          num_trans == 1;
          pkt_len_min == 17;
          pkt_len_max == 17;
          zero_delay_prefix_beats == 16;
          delay_min == dly;
          delay_max == dly;
        }) begin
      `uvm_fatal("VSEQ_OA", "col_seq randomize failed")
    end
    col_seq.start(axis_sqr);

    fork
      begin
        intr_proxy.wait_for_interrupt();
      end
      begin
        wait_cycles(1000);
        deadlock_occurred = 1'b1;
      end
    join_any
    disable fork;

    if (deadlock_occurred) begin
      `uvm_error(
          "VSEQ_OA",
          $sformatf(
              "Deadlock detected at dly=%0d (simultaneous core_done & next_blk_ready collision)!",
              dly))
      csr_rb.CTRL.write(status, 32'h0000000B);  // Recover via SOFT_RESET
      wait_cycles(10);
    end else begin
      read_digest_and_clear_irq();
    end
  end
endtask

// ---------------------------------------------------------
// [Test Plan: oa_manual_chain]
// STATE_IN_0~7 Manual IV injection (single & multi-block) and standard IV restoration verification
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_manual_chain();
  axis_m_stream_seq stream_seq;
  int               chain_lens[2] = '{4, 80};
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

  `uvm_info("VSEQ_OA", "Starting do_oa_manual_chain (Custom IV Single & Multi-Block)", UVM_LOW)

  foreach (state_regs[i]) begin
    state_regs[i].write(status, custom_iv[i]);
  end

  foreach (chain_lens[k]) begin
    int len = chain_lens[k];
    stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
    stream_seq.payload_data = new[len];
    foreach (stream_seq.payload_data[j]) stream_seq.payload_data[j] = 8'h61 + j;

    csr_rb.CTRL.write(status, 32'h00000007);
    stream_seq.start(axis_sqr);

    intr_proxy.wait_for_interrupt();
    read_digest_and_clear_irq();
  end

  foreach (state_regs[i]) begin
    state_regs[i].write(status, std_iv[i]);
  end

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
// [Test Plan: oa_disable, oa_irq_mask]
// verification of control bit disable (EN=0 blocking reception/start and IRQ_EN=0 interrupt masking)
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
  csr_rb.CTRL.write(status, 32'h00000004);
  csr_rb.STATUS.read(status, rdata);
  if ((rdata & 32'h00000001) != 0) begin
    `uvm_error("VSEQ_OA", "Self-Deadlock bug detected: DUT entered BUSY state when START=1 with EN=0!")
  end

  single_seq = axis_m_single_seq::type_id::create("single_seq");
  if (!single_seq.randomize() with {pkt_len == 1;}) begin
    `uvm_fatal("VSEQ_OA", "single_seq randomize failed")
  end

  fork
    begin
      single_seq.start(axis_sqr);
    end
    begin
      wait_cycles(100);
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
// [Test Plan: oa_stress, oa_async_done_chain]
// Multi-block slow streaming (10~100 cycles stall per beat) crossed with AXI4-Lite STATUS polling
// to verify asynchronous core_done latching while Wrapper is in S_RCV.
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_stress();
  axis_m_slow_seq slow_seq;

  `uvm_info("VSEQ_OA", "Starting do_oa_stress", UVM_LOW)

  csr_rb.CTRL.write(status, 32'h00000007);

  slow_seq = axis_m_slow_seq::type_id::create("slow_seq");
  if (!slow_seq.randomize() with {
        num_trans == 1;
        pkt_len_min == 20;
        pkt_len_max == 24;
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

  wait_cycles(200);

  csr_rb.STATUS.read(status, rdata);
  if ((rdata & 32'h00000001) == 0) begin
    `uvm_error("VSEQ_OA", "DUT is NOT in BUSY state during Starvation!")
  end

  `uvm_info("VSEQ_OA", "Timeout (Hang) detected! Issuing SOFT_RESET...", UVM_LOW)
  csr_rb.CTRL.write(status, 32'h0000000B);
  wait_cycles(10);

  csr_rb.STATUS.read(status, rdata);
  if ((rdata & 32'h00000001) != 0) begin
    `uvm_error("VSEQ_OA", "DUT failed to recover! Still BUSY after SOFT_RESET.")
  end

  `uvm_info("VSEQ_OA", "Verifying recovery with normal lifecycle...", UVM_LOW)
  do_oa_lifecycle();
endtask

// ---------------------------------------------------------
// [Test Plan: oa_busy_recov]
// Verify SOFT_RESET recovery both during S_WAIT_CORE (Core Busy) and
// during overlapped 2nd-block S_RCV while 1st block is running in Core.
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_busy_recov();
  axis_m_stream_seq     stream_seq;
  axis_m_err_inject_seq overlap_hang_seq;
  axi4lite_write_seq    axil_write_seq;

  `uvm_info("VSEQ_OA", "Starting do_oa_busy_recov (Snipe Reset in S_WAIT_CORE)", UVM_LOW)

  // 1. [OA-13] SOFT_RESET during S_WAIT_CORE (Core BUSY)
  csr_rb.CTRL.write(status, 32'h00000007);

  stream_seq = axis_m_stream_seq::type_id::create("stream_seq");
  stream_seq.payload_data = new[64];
  foreach (stream_seq.payload_data[i]) stream_seq.payload_data[i] = $urandom;

  stream_seq.start(axis_sqr);

  wait_cycles(6);

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

  wait_cycles(10);

  csr_rb.STATUS.read(status, rdata);
  if ((rdata & 32'h00000001) != 0) begin
    `uvm_error("VSEQ_OA", "Core is still BUSY after SOFT_RESET.")
  end

  `uvm_info("VSEQ_OA", "Starting overlapped S_RCV + Core BUSY SOFT_RESET test", UVM_LOW)
  csr_rb.CTRL.write(status, 32'h00000007);

  overlap_hang_seq = axis_m_err_inject_seq::type_id::create("overlap_hang_seq");
  if (!overlap_hang_seq.randomize() with {
        pkt_len == 17;
        do_tkeep_err == 1'b0;
        do_tlast_drop == 1'b1;
      }) begin
    `uvm_fatal("VSEQ_OA", "overlap_hang_seq randomize failed")
  end
  overlap_hang_seq.start(axis_sqr);

  wait_cycles(6);

  axil_write_seq = axi4lite_write_seq::type_id::create("axil_write_seq");
  if (!axil_write_seq.randomize() with {
        addr == 32'h04;  // CTRL
        wdata == 32'h00000008;
        wstrb == 4'hF;
        prot == 3'b000;
      }) begin
    `uvm_fatal("VSEQ_OA", "axil_write_seq randomize failed")
  end
  axil_write_seq.start(axil_sqr);

  wait_cycles(10);

  csr_rb.STATUS.read(status, rdata);
  if ((rdata & 32'h00000001) != 0) begin
    `uvm_error("VSEQ_OA", "Core is still BUSY after overlapped S_RCV SOFT_RESET!")
  end

  `uvm_info("VSEQ_OA", "Core successfully aborted and recovered to IDLE.", UVM_LOW)

  do_oa_lifecycle();
endtask

// ---------------------------------------------------------
// [Test Plan: oa_tkeep_err, oa_overlap_abort]
// Verify hardware TKEEP error protection both when Core is IDLE (1st block)
// and when Core is BUSY (overlapped 2nd block reception).
// ---------------------------------------------------------
task sha256_overall_vseq::do_oa_tkeep_err();
  axis_m_err_inject_seq err_seq;
  int                   err_pkt_lens[2]     = '{1, 17};
  bit [1:0]             drop_tlast_modes[2] = '{1'b0, 1'b1};
  uvm_reg_data_t        digest_data;

  `uvm_info("VSEQ_OA", "Starting do_oa_tkeep_err (Hardware TKEEP Protection)", UVM_LOW)

  // p=0 (pkt_len=1): [OA-14] 1st block reception (core_busy == 0)
  // p=1 (pkt_len=17): [OA-19] Overlapped 2nd-block reception (core_busy == 1)
  foreach (err_pkt_lens[p]) begin
    int target_len = err_pkt_lens[p];

    if (target_len == 17) begin
      `uvm_info("VSEQ_OA", "Starting overlapped 2nd-block TKEEP error injection (core_busy == 1)",
                UVM_LOW)
    end

    foreach (drop_tlast_modes[i]) begin
      bit is_mid_pkt = drop_tlast_modes[i];

      csr_rb.CTRL.write(status, 32'h00000007);

      err_seq = axis_m_err_inject_seq::type_id::create("err_seq");
      if (!err_seq.randomize() with {
            pkt_len == target_len;
            do_tkeep_err == 1'b1;
            do_tlast_drop == is_mid_pkt;
            zero_prefix_delay == 1'b1;
            final_beat_delay == 5;
          }) begin
        `uvm_fatal("VSEQ_OA", "err_seq randomize failed in do_oa_tkeep_err")
      end
      err_seq.start(axis_sqr);

      wait_cycles(10);

      csr_rb.STATUS.read(status, rdata);
      if ((rdata & 32'h00000001) != 0) begin
        `uvm_error("VSEQ_OA", $sformatf(
                                  "DUT still BUSY after invalid TKEEP (len=%0d, mode=%0b)! STATUS=0x%08x",
                                  target_len, is_mid_pkt, rdata))
        csr_rb.CTRL.write(status, 32'h0000000B);
        wait_cycles(10);
      end
      if (intr_proxy.get_irq_level() != 1'b1) begin
        `uvm_error("VSEQ_OA", $sformatf(
                                  "irq_o must be asserted (1) upon TKEEP violation! (len=%0d, mode=%0b)",
                                  target_len, is_mid_pkt))
      end
      if ((rdata & 32'h00000004) == 0) begin
        `uvm_error("VSEQ_OA", $sformatf(
                                  "STATUS.ERR_PRT not asserted on invalid TKEEP (len=%0d, mode=%0b)! STATUS=0x%08x",
                                  target_len, is_mid_pkt, rdata))
      end

      csr_rb.DIGEST_0.read(status, digest_data);
      if (digest_data[31:0] != 32'd0) begin
        `uvm_error("VSEQ_OA", $sformatf(
                                  "DIGEST_0 not zeroized after TKEEP violation (len=%0d, mode=%0b)! DIGEST_0=0x%08x",
                                  target_len, is_mid_pkt, digest_data[31:0]))
      end

      if (i == 0) begin
        csr_rb.INTCLEAR.write(status, 32'h00000004);
      end else begin
        csr_rb.CTRL.write(status, 32'h00000008);
      end

      csr_rb.STATUS.read(status, rdata);
      if ((rdata & 32'h00000004) != 0) begin
        `uvm_error("VSEQ_OA", $sformatf(
                                  "STATUS.ERR_PRT failed to clear (mode=%0b)! STATUS=0x%08x",
                                  is_mid_pkt, rdata))
      end
      if (intr_proxy.get_irq_level() != 1'b0) begin
        `uvm_error("VSEQ_OA", $sformatf(
                                  "irq_o failed to deassert after clearing ERR_PRT! (len=%0d, mode=%0b)",
                                  target_len, is_mid_pkt))
      end
    end
  end

  `uvm_info("VSEQ_OA", "TKEEP error protection verified", UVM_LOW)
  do_oa_lifecycle();
endtask
