class sha256_overall_coverage extends uvm_component;
  `uvm_component_utils(sha256_overall_coverage)

  uvm_tlm_analysis_fifo #(axi4lite_seq_item) axil_fifo;
  uvm_tlm_analysis_fifo #(axis_seq_item)     axis_fifo;
  uvm_tlm_analysis_fifo #(core_seq_item)     core_fifo;

  sha256_csr                                 csr_rb;
  bit                                        core_aborted_by_rst = 0;

  covergroup cg_payload with function sample (
      int payload_bytes, bit is_multi_blk, bit is_word_aligned, bit is_all_80
  );
    option.per_instance = 1;
    cp_msg_len: coverpoint payload_bytes {
      // [Waiver: oa_zero_len] 0-byte transfer (TKEEP=0) is not driven by VIP/DMA
      //bins len_0 = {0};
      bins len_55 = {55};
      bins len_56 = {56};
      bins len_64 = {64};
      bins len_119 = {119};
      bins len_120 = {120};
      bins len_128 = {128};
      bins single_block = {[1 : 54], [57 : 63]};
      bins multi_block = {[65 : 118], [121 : 127], [129 : 2048]};
      bins others = default;
    }
    cp_all80_edge: coverpoint payload_bytes iff (is_all_80) {
      bins edge_len[] = {1, 55, 56, 63, 64, 119, 120, 127, 128};
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
      int           pkt_len = 0;
      bit           is_all_80 = 1'b1;

      axis_fifo.get(axis_item);
      if (axis_item.status != axis_seq_item::OK) continue;

      foreach (axis_item.tkeep_q[i]) begin
        for (int b = 0; b < 4; b++) begin
          if (axis_item.tkeep_q[i][b]) begin
            pkt_len++;
            if (axis_item.tdata_q[i][(b*8)+:8] != 8'h80) begin
              is_all_80 = 1'b0;
            end
          end
        end
      end
      cg_payload.sample(pkt_len, (pkt_len > 64), ((pkt_len % 4) == 0), (pkt_len > 0 && is_all_80));
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
      if (csr_rb == null || axil_item.resp != 2'b00) continue;

      target_reg = csr_rb.default_map.get_reg_by_offset({56'd0, axil_item.addr[7:0]});
      if (target_reg == null) continue;

      if (axil_item.dir == axi4lite_seq_item::READ && target_reg == csr_rb.STATUS) begin
        if (axil_item.rdata[0] == 1'b0) begin
          core_aborted_by_rst = 1'b0;
        end
      end else if (axil_item.dir == axi4lite_seq_item::WRITE &&
                   target_reg == csr_rb.CTRL && axil_item.wstrb[0]) begin
        int soft_rst_pos = csr_rb.CTRL.SOFT_RESET.get_lsb_pos();
        is_soft_rst = (axil_item.wdata >> soft_rst_pos) & 1'b1;

        if (is_soft_rst) begin
          is_busy = core_aborted_by_rst;
          cg_exception.sample(is_busy);
          core_aborted_by_rst = 1'b0;
        end
      end
    end
  join
endtask
