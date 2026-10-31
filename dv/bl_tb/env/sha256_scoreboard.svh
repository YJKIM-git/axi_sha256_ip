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
  int unsigned                               expected_hash          [8];
  int unsigned                               actual_hash            [8];
  int                                        digest_words_collected;

  extern function new(string name = "sha256_scoreboard", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

  extern task process_axil_data(axi4lite_seq_item item);
  extern task process_axis_data(axis_seq_item item);
  extern task process_core_data(core_seq_item item);

  extern function void compare_hash();
endclass : sha256_scoreboard

function sha256_scoreboard::new(string name = "sha256_scoreboard", uvm_component parent = null);
  super.new(name, parent);
  digest_words_collected = 0;
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
  join
endtask

// ------------------------------------------------------------------
// [Thread A] Collect AXI4-Lite data (output parsing and grading trigger)
// ------------------------------------------------------------------
task sha256_scoreboard::process_axil_data(axi4lite_seq_item item);
  uvm_reg target_reg;
  string  reg_name;
  int     reg_idx;

  if (item == null) return;
  if (!m_cfg.enable_sb_check) return;

  if (item.dir == axi4lite_seq_item::READ) begin

    if (item.resp != 2'b00 && item.resp != 2'b01) begin : invalid_read
      `uvm_info("SB_AXIL", $sformatf("Ignored invalid read response (Resp: %0b) at Addr: 0x%0h",
                                     item.resp, item.addr), UVM_HIGH)
      return;
    end

    if (csr_rb == null) begin : null_csr_rb
      `uvm_error("SB_RAL", "csr_rb is null in scoreboard. Cannot perform reverse lookup.")
      return;
    end
    target_reg = csr_rb.default_map.get_reg_by_offset(item.addr);

    if (target_reg != null) begin
      reg_name = target_reg.get_name();

      if (reg_name.len() >= 8 && reg_name.substr(0, 6) == "DIGEST_") begin : digest_reg
        reg_idx = reg_name.substr(7, 7).atoi(); // extract the DIGEST idx
        actual_hash[reg_idx] = item.rdata[31:0];
        digest_words_collected++;

        if (digest_words_collected == 8) begin : grading
          compare_hash();
          digest_words_collected = 0;
          msg_queue.delete();
        end
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

  // [TEST_PLAN: oa_recovery] AXI-Stream 주입 중 교착 상태 및 비정상 패킷(Hang) 필터링
  // 비정상 패킷이 감지되면 현재까지 쌓인 큐를 비워내어 다음 트랜잭션 채점에 오염을 방지함.
  if (item.status != axis_seq_item::OK) begin
    `uvm_info("oa_recovery",
              $sformatf("Abnormal packet detected (Status: %s). Flushing queue to maintain sync.",
                        item.status.name()), UVM_MEDIUM)
    msg_queue.delete();
    return;
  end

  // 패킷 내의 모든 전송(beat)을 순회하며 유효한 바이트만 추출
  foreach (item.tdata_q[i]) begin
    logic [31:0] beat_data = item.tdata_q[i][31:0];
    logic [ 3:0] beat_keep = item.tkeep_q[i][3:0];

    // Little-Endian 버스이므로 LSB(Byte 0)부터 검사
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
// [Thread C] Comare Hash Result and Grade
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

  if (len == 55 || len == 56 || len == 64) begin
    test_plan_id = "oa_pad_edge";
  end else begin
    test_plan_id = "oa_byte_swap / Datapath";
  end

  c_sha256_digest(msg_array, len, expected_hash); // call the DPI-C

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
    msg_queue.delete();
    return;
  end

  `uvm_info("SB_CORE", $sformatf("Core Hash Done. Latency=%0d", item.latency), UVM_HIGH)
endtask
