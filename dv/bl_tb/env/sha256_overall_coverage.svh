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
//   - Defines end-to-end SHA-256 payload and recovery coverage.
//------------------------------------------------------------------------------

class sha256_overall_coverage extends uvm_component;
  `uvm_component_utils(sha256_overall_coverage)

  uvm_tlm_analysis_fifo #(axi4lite_seq_item) axil_fifo;
  uvm_tlm_analysis_fifo #(axis_seq_item)     axis_fifo;
  uvm_tlm_analysis_fifo #(core_seq_item)     core_fifo;

  sha256_csr                                 csr_rb;
  bit                                        core_aborted_by_rst = 0;

  covergroup cg_payload with function sample (
      int payload_bytes, bit is_multi_blk, bit is_word_aligned
  );
    option.per_instance = 1;
    cp_msg_len: coverpoint payload_bytes {
      // [Waiver: oa_zero_len] 0-byte transfer (TKEEP=0) is not driven by VIP/DMA
      //bins len_0 = {0};
      bins len_55 = {55};
      bins len_56 = {56};
      bins len_64 = {64};
      bins single_block = {[1 : 54], [57 : 63]};
      bins multi_block = {[65 : 2048]};
      bins others = default;
    }
    cp_block_mode: coverpoint is_multi_blk {bins single_blk = {0}; bins multi_blk = {1};}
    cp_last_align: coverpoint is_word_aligned {
      bins unaligned_partial = {0}; bins word_aligned = {1};
    }
    cr_block_align: cross cp_block_mode, cp_last_align;
  endgroup

  covergroup cg_exception with function sample (bit is_busy);
    option.per_instance = 1;

    cp_rst_status: coverpoint is_busy {bins rst_while_busy = {1}; bins rst_while_idle = {0};}
  endgroup

  extern function new(string name = "sha256_overall_coverage", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

endclass : sha256_overall_coverage

function sha256_overall_coverage::new(string name = "sha256_overall_coverage",
                                      uvm_component parent = null);
  super.new(name, parent);
  cg_payload   = new();
  cg_exception = new();
endfunction

function void sha256_overall_coverage::build_phase(uvm_phase phase);
  super.build_phase(phase);
  axil_fifo = new("axil_fifo", this);
  axis_fifo = new("axis_fifo", this);
  core_fifo = new("core_fifo", this);
endfunction

task sha256_overall_coverage::run_phase(uvm_phase phase);
  fork
    forever begin
      axis_seq_item axis_item;
      int pkt_len = 0;

      axis_fifo.get(axis_item);

      // Ignore incomplete packets aborted by reset or timeout
      if (axis_item.status != axis_seq_item::OK) continue;

      foreach (axis_item.tkeep_q[i]) begin
        for (int b = 0; b < 4; b++) begin
          if (axis_item.tkeep_q[i][b]) pkt_len++;
        end
      end
      cg_payload.sample(pkt_len, (pkt_len > 64), ((pkt_len % 4) == 0));
    end

    forever begin
      core_seq_item core_item;
      core_fifo.get(core_item);
      if (core_item != null) begin
        core_aborted_by_rst = core_item.is_aborted;
      end
    end

    forever begin
      axi4lite_seq_item axil_item;
      uvm_reg           target_reg;
      bit               is_soft_rst;
      bit               is_busy;

      axil_fifo.get(axil_item);

      if (csr_rb == null) continue;

      if (axil_item.dir == axi4lite_seq_item::WRITE && axil_item.resp == 2'b00) begin
        target_reg = csr_rb.default_map.get_reg_by_offset(axil_item.addr);

        if (target_reg != null && target_reg == csr_rb.CTRL) begin
          int soft_rst_pos = csr_rb.CTRL.SOFT_RESET.get_lsb_pos();
          is_soft_rst = (axil_item.wdata >> soft_rst_pos) & 1'b1;

          // Sample Soft Reset context using core_aborted_by_rst tracked from core_fifo
          if (is_soft_rst) begin
            is_busy = core_aborted_by_rst;
            cg_exception.sample(is_busy);
            core_aborted_by_rst = 0;
          end
        end
      end
    end
  join
endtask
