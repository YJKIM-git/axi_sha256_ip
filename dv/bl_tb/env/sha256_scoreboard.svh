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
//   - Checks SHA-256 AXI and stream behavior against expected transactions and reference results.
//------------------------------------------------------------------------------

import "DPI-C" context function void c_sha256_digest(
  input byte msg[],
  input int msg_len,
  input int unsigned custom_iv[8],
  output int unsigned expected_hash[8]
);

class sha256_scoreboard extends uvm_component;
  `uvm_component_utils(sha256_scoreboard)

  uvm_tlm_analysis_fifo #(axi4lite_seq_item) axil_fifo;
  uvm_tlm_analysis_fifo #(axis_seq_item)     axis_fifo;
  uvm_tlm_analysis_fifo #(core_seq_item)     core_fifo;

  sha256_csr                                 csr_rb;
  sha256_env_config                          m_cfg;

  byte                                       msg_queue              [$];
  int unsigned                               active_iv              [8];
  int unsigned                               expected_hash          [8];
  int unsigned                               actual_hash            [8];
  int                                        digest_words_collected;
  bit                                        sb_busy;

  extern function new(string name = "sha256_scoreboard", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

  extern function void reset_iv();
  extern function bit is_custom_iv();
  extern function void check_axil_response(axi4lite_seq_item item, uvm_reg target_reg);
  extern task process_axil_data(axi4lite_seq_item item);
  extern task process_axis_data(axis_seq_item item);
  extern task process_core_data(core_seq_item item);

  extern function void compare_hash();
endclass : sha256_scoreboard

function sha256_scoreboard::new(string name = "sha256_scoreboard", uvm_component parent = null);
  super.new(name, parent);
  digest_words_collected = 0;
  sb_busy                = 1'b0;
  reset_iv();
endfunction

function void sha256_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
  axil_fifo = new("axil_fifo", this);
  axis_fifo = new("axis_fifo", this);
  core_fifo = new("core_fifo", this);
  m_cfg = sha256_env_config::get_config(this);
endfunction

task sha256_scoreboard::run_phase(uvm_phase phase);
  fork
    forever begin
      axi4lite_seq_item axil_item;
      axil_fifo.get(axil_item);
      process_axil_data(axil_item);
    end

    forever begin
      axis_seq_item axis_item;
      axis_fifo.get(axis_item);
      process_axis_data(axis_item);
    end

    forever begin
      core_seq_item core_item;
      core_fifo.get(core_item);
      process_core_data(core_item);
    end

    forever begin
      m_cfg.m_rst_util.wait_for_reset();
      sb_busy                = 1'b0;
      digest_words_collected = 0;
      msg_queue.delete();
      reset_iv();
    end
  join
endtask

function void sha256_scoreboard::reset_iv();
  active_iv = '{
      32'h6a09e667,
      32'hbb67ae85,
      32'h3c6ef372,
      32'ha54ff53a,
      32'h510e527f,
      32'h9b05688c,
      32'h1f83d9ab,
      32'h5be0cd19
  };
endfunction

function bit sha256_scoreboard::is_custom_iv();
  int unsigned std_iv[8] = '{
      32'h6a09e667,
      32'hbb67ae85,
      32'h3c6ef372,
      32'ha54ff53a,
      32'h510e527f,
      32'h9b05688c,
      32'h1f83d9ab,
      32'h5be0cd19
  };
  foreach (active_iv[i]) begin
    if (active_iv[i] !== std_iv[i]) return 1'b1;
  end
  return 1'b0;
endfunction

function void sha256_scoreboard::check_axil_response(axi4lite_seq_item item, uvm_reg target_reg);
  logic         [1:0] exp_resp;
  uvm_reg_field       fields   [$];
  string              rights;

  if ((item.prot[1] == 1'b1) || (item.addr[1:0] != 2'b00)) begin
    exp_resp = 2'b10;  // Non-secure or unaligned access -> SLVERR
  end else if (target_reg == null) begin
    exp_resp = 2'b11;  // Unmapped address -> DECERR
  end else begin
    target_reg.get_fields(fields);
    rights = (fields.size() > 0) ? fields[0].get_access() : "RW";
    if (item.dir == axi4lite_seq_item::READ) begin
      exp_resp = (rights == "WO") ? 2'b11 : 2'b00;
    end else begin
      if (rights == "RO") begin
        exp_resp = 2'b10;
      end else if (rights == "WO") begin
        exp_resp = 2'b00;
      end else begin  // "RW" (CTRL, STATE_IN_0~7)
        if (sb_busy) begin
          if (target_reg == csr_rb.CTRL && item.wstrb[0] && item.wdata[3]) begin
            exp_resp = 2'b00;
          end else begin
            exp_resp = 2'b10;  // Atomicity violation during BUSY -> SLVERR
          end
        end else begin
          exp_resp = 2'b00;
        end
      end
    end
  end

  if (item.resp !== exp_resp) begin
    `uvm_error(
        "SB_CSR_RESP",
        $sformatf(
            "AXI4-Lite %s resp mismatch at addr=0x%02h (prot[1]=%0b, busy=%0b, wstrb=0x%0h, wdata=0x%08x): expected %0b, got %0b",
            item.dir.name(), item.addr[7:0], item.prot[1], sb_busy, item.wstrb[3:0],
            item.wdata[31:0], exp_resp, item.resp))
  end

  if (item.dir == axi4lite_seq_item::READ && exp_resp != 2'b00 && item.rdata[31:0] !== 32'd0) begin
    `uvm_error("SB_CSR_MASK",
               $sformatf("AXI4-Lite READ error data not masked to 0 at addr=0x%02h: got 0x%08x",
                         item.addr[7:0], item.rdata[31:0]))
  end
endfunction

// ------------------------------------------------------------------
// [Thread A] Collect AXI4-Lite data (CSR response check, IV/Busy tracking, and grading trigger)
// ------------------------------------------------------------------
task sha256_scoreboard::process_axil_data(axi4lite_seq_item item);
  uvm_reg target_reg;
  string  reg_name;
  int     reg_idx;

  if (item == null) return;

  if (csr_rb == null) begin : null_csr_rb
    `uvm_error("SB_RAL", "csr_rb is null in scoreboard. Cannot perform reverse lookup.")
    return;
  end

  target_reg = csr_rb.default_map.get_reg_by_offset({56'd0, item.addr[7:0]});

  check_axil_response(item, target_reg);

  if (item.resp == 2'b00 && target_reg != null) begin
    reg_name = target_reg.get_name();
    if (item.dir == axi4lite_seq_item::WRITE) begin
      if (target_reg == csr_rb.CTRL && item.wstrb[0]) begin
        if (item.wdata[3]) begin
          sb_busy                = 1'b0;
          digest_words_collected = 0;
          msg_queue.delete();
          reset_iv();
        end else if (!sb_busy && item.wdata[2] && item.wdata[0]) begin
          sb_busy = 1'b1;
        end
      end else if (target_reg == csr_rb.INTCLEAR && item.wstrb[0]) begin
        if (item.wdata[1] || item.wdata[2]) sb_busy = 1'b0;
      end else if (reg_name.len() >= 10 && reg_name.substr(0, 8) == "STATE_IN_") begin
        reg_idx = reg_name.substr(9, 9).atoi();
        for (int b = 0; b < 4; b++) begin
          if (item.wstrb[b]) begin
            active_iv[reg_idx][(b*8)+:8] = item.wdata[(b*8)+:8];
          end
        end
      end
    end else begin  // READ with OKAY
      if (target_reg == csr_rb.STATUS) begin
        sb_busy = item.rdata[0];
      end else if (reg_name.len() >= 8 && reg_name.substr(0, 6) == "DIGEST_") begin
        sb_busy = 1'b0;
      end
    end
  end

  if (!m_cfg.enable_sb_check) return;

  if (item.dir == axi4lite_seq_item::READ && item.resp == 2'b00 && target_reg != null) begin
    reg_name = target_reg.get_name();
    if (reg_name.len() >= 8 && reg_name.substr(0, 6) == "DIGEST_") begin : digest_reg
      reg_idx = reg_name.substr(7, 7).atoi();
      actual_hash[reg_idx] = item.rdata[31:0];
      digest_words_collected++;

      if (digest_words_collected == 8) begin : grading
        compare_hash();
        digest_words_collected = 0;
        msg_queue.delete();
      end
    end
  end
endtask

// ------------------------------------------------------------------
// [Thread B] Collect AXIS data (input parsing)
// ------------------------------------------------------------------
task sha256_scoreboard::process_axis_data(axis_seq_item item);
  if (item == null) return;
  if (!m_cfg.enable_sb_check) return;

  if (item.status != axis_seq_item::OK) begin
    `uvm_info("oa_recovery",
              $sformatf("Abnormal packet detected (Status: %s). Flushing queue to maintain sync.",
                        item.status.name()), UVM_MEDIUM)
    msg_queue.delete();
    return;
  end

  foreach (item.tdata_q[i]) begin
    logic [31:0] beat_data = item.tdata_q[i][31:0];
    logic [ 3:0] beat_keep = item.tkeep_q[i][3:0];

    for (int b = 0; b < 4; b++) begin
      if (beat_keep[b] == 1'b1) begin
        msg_queue.push_back(beat_data[(b*8)+:8]);
      end
    end
  end

  `uvm_info("SB_AXIS", $sformatf("AXIS Packet Received. Total payload bytes collected so far: %0d",
                                 msg_queue.size()), UVM_HIGH)
endtask


// ------------------------------------------------------------------
// [Thread C] Compare Hash Result and Grade
// ------------------------------------------------------------------
function void sha256_scoreboard::compare_hash();
  byte msg_array[];
  string expected_str = "";
  string actual_str = "";
  bit is_match = 1;
  int len;
  string test_plan_id;

  len = msg_queue.size();
  msg_array = new[len] (msg_queue);

  if (is_custom_iv()) begin
    test_plan_id = "oa_manual_chain";
  end else if (len == 55 || len == 56 || len == 64) begin
    test_plan_id = "oa_pad_edge";
  end else begin
    test_plan_id = "oa_byte_swap / Datapath";
  end

  c_sha256_digest(msg_array, len, active_iv, expected_hash);

  for (int i = 0; i < 8; i++) begin : hash_compare
    expected_str = {expected_str, $sformatf("%08x", expected_hash[i])};
    actual_str   = {actual_str, $sformatf("%08x", actual_hash[i])};

    if (expected_hash[i] !== actual_hash[i]) begin
      is_match = 0;
    end
  end

  if (is_match) begin
    `uvm_info(test_plan_id, $sformatf("[PASS] Hash Match! Length: %0d Bytes\nHash: %s", len,
                                      actual_str), UVM_LOW)
  end else begin
    `uvm_error(test_plan_id, $sformatf(
               "[FAIL] Hash Mismatch! Length: %0d Bytes\nExpected: %s\nActual  : %s",
               len,
               expected_str,
               actual_str
               ))
  end
endfunction

// ------------------------------------------------------------------
// [Thread D] Core internal state monitoring (for debugging assistance)
// ------------------------------------------------------------------
task sha256_scoreboard::process_core_data(core_seq_item item);
  if (item == null) return;
  if (item.is_aborted) begin
    sb_busy = 1'b0;
    msg_queue.delete();
    return;
  end

  `uvm_info("SB_CORE", $sformatf("Core Hash Done. Latency=%0d", item.latency), UVM_HIGH)
endtask
