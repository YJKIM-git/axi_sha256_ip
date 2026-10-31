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
//   - Completely rewrote the protocol-specific logic, interfaces, and sequences for the AXI4-Lite protocol.
//------------------------------------------------------------------------------

covergroup cg_axi4lite_32b_normal with function sample (axi4lite_seq_item txn);
  option.per_instance = 1;

  DIR: coverpoint txn.dir {
    bins write = {axi4lite_seq_item::WRITE}; bins read = {axi4lite_seq_item::READ};
  }

  RESP: coverpoint txn.resp {bins okay = {2'b00};}

  WSTRB_32B: coverpoint txn.wstrb[3:0] iff (txn.dir == axi4lite_seq_item::WRITE) {
    bins all_zeros = {4'h0}; bins all_ones = {4'hF}; bins partial = {[4'h1 : 4'hE]};
  }

  PROT: coverpoint txn.prot {
    bins unpriv_secure_data = {3'b000};
    bins priv_secure_data = {3'b001};
    bins unpriv_nonsecure_data = {3'b010};
    bins priv_nonsecure_data = {3'b011};
    bins unpriv_secure_inst = {3'b100};
    bins priv_secure_inst = {3'b101};
    bins unpriv_nonsecure_inst = {3'b110};
    bins priv_nonsecure_inst = {3'b111};
  }

  ALIGN_32B: coverpoint txn.addr[1:0] {bins aligned = {2'b00};}

  // [WV-AXIL-04, 05] 0-cycle handshake is unreachable due to registered (always_ff) slave outputs
  AW_DELAY: coverpoint txn.aw_delay iff (txn.dir == axi4lite_seq_item::WRITE) {
    ignore_bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  W_DELAY: coverpoint txn.w_delay iff (txn.dir == axi4lite_seq_item::WRITE) {
    ignore_bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  B_DELAY: coverpoint txn.b_delay iff (txn.dir == axi4lite_seq_item::WRITE) {
    ignore_bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  AR_DELAY: coverpoint txn.ar_delay iff (txn.dir == axi4lite_seq_item::READ) {
    ignore_bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  R_DELAY: coverpoint txn.r_delay iff (txn.dir == axi4lite_seq_item::READ) {
    ignore_bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  CROSS_DIR_RESP: cross DIR, RESP;
  CROSS_WRITE_WSTRB_32B: cross DIR, WSTRB_32B;
  CROSS_DIR_ALIGN32: cross DIR, ALIGN_32B;
  CROSS_AW_W_DELAY: cross AW_DELAY, W_DELAY;
endgroup

covergroup cg_axi4lite_32b_error with function sample (axi4lite_seq_item txn);
  option.per_instance = 1;

  DIR: coverpoint txn.dir {
    bins write = {axi4lite_seq_item::WRITE}; bins read = {axi4lite_seq_item::READ};
  }

  // [WV-AXIL-07] DECERR is address-map dependent and verified in sha256_csr_coverage
  ERR_RESP: coverpoint txn.resp {
    bins slverr = {2'b10}; ignore_bins decerr = {2'b11};
  }

  ERR_ALIGN_32B: coverpoint txn.addr[1:0] {bins unaligned = {[2'b01 : 2'b11]};}

  CROSS_DIR_ERR_RESP: cross DIR, ERR_RESP;
  CROSS_DIR_ERR_ALIGN32: cross DIR, ERR_ALIGN_32B;
endgroup

covergroup cg_axi4lite_64b_normal with function sample (axi4lite_seq_item txn);
  option.per_instance = 1;

  DIR: coverpoint txn.dir {
    bins write = {axi4lite_seq_item::WRITE}; bins read = {axi4lite_seq_item::READ};
  }

  RESP: coverpoint txn.resp {bins okay = {2'b00};}

  WSTRB_64B: coverpoint txn.wstrb iff (txn.dir == axi4lite_seq_item::WRITE) {
    bins all_zeros = {8'h00}; bins all_ones = {8'hFF}; bins partial = {[8'h01 : 8'hFE]};
  }

  PROT: coverpoint txn.prot {
    bins unpriv_secure_data = {3'b000};
    bins priv_secure_data = {3'b001};
    bins unpriv_nonsecure_data = {3'b010};
    bins priv_nonsecure_data = {3'b011};
    bins unpriv_secure_inst = {3'b100};
    bins priv_secure_inst = {3'b101};
    bins unpriv_nonsecure_inst = {3'b110};
    bins priv_nonsecure_inst = {3'b111};
  }

  ALIGN_64B: coverpoint txn.addr[2:0] {bins aligned = {3'b000};}

  AW_DELAY: coverpoint txn.aw_delay iff (txn.dir == axi4lite_seq_item::WRITE) {
    bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  W_DELAY: coverpoint txn.w_delay iff (txn.dir == axi4lite_seq_item::WRITE) {
    bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  B_DELAY: coverpoint txn.b_delay iff (txn.dir == axi4lite_seq_item::WRITE) {
    bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  AR_DELAY: coverpoint txn.ar_delay iff (txn.dir == axi4lite_seq_item::READ) {
    bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  R_DELAY: coverpoint txn.r_delay iff (txn.dir == axi4lite_seq_item::READ) {
    bins back_to_back = {0}; bins delayed = {[1 : 20]};
  }

  CROSS_DIR_RESP: cross DIR, RESP;
  CROSS_WRITE_WSTRB_64B: cross DIR, WSTRB_64B;
  CROSS_DIR_ALIGN64: cross DIR, ALIGN_64B;
  CROSS_AW_W_DELAY: cross AW_DELAY, W_DELAY;
endgroup

covergroup cg_axi4lite_64b_error with function sample (axi4lite_seq_item txn);
  option.per_instance = 1;

  DIR: coverpoint txn.dir {
    bins write = {axi4lite_seq_item::WRITE}; bins read = {axi4lite_seq_item::READ};
  }

  ERR_RESP: coverpoint txn.resp {bins slverr = {2'b10}; bins decerr = {2'b11};}

  ERR_ALIGN_64B: coverpoint txn.addr[2:0] {bins unaligned = {[3'b001 : 3'b111]};}

  CROSS_DIR_ERR_RESP: cross DIR, ERR_RESP;
  CROSS_DIR_ERR_ALIGN64: cross DIR, ERR_ALIGN_64B;
endgroup

class axi4lite_coverage_monitor extends uvm_subscriber #(axi4lite_seq_item);

  `uvm_component_utils(axi4lite_coverage_monitor)

  axi4lite_agent_config m_cfg;
  axi4lite_seq_item analysis_txn;

  cg_axi4lite_32b_normal cov_32b_normal;
  cg_axi4lite_32b_error cov_32b_error;
  cg_axi4lite_64b_normal cov_64b_normal;
  cg_axi4lite_64b_error cov_64b_error;

  extern function new(string name = "axi4lite_coverage_monitor", uvm_component parent = null);
  extern function void write(axi4lite_seq_item t);
  extern function void report_phase(uvm_phase phase);

endclass : axi4lite_coverage_monitor

function axi4lite_coverage_monitor::new(string name = "axi4lite_coverage_monitor",
                                        uvm_component parent = null);
  super.new(name, parent);

  if (uvm_config_db#(axi4lite_agent_config)::get(this, "", "axi4lite_agent_config", m_cfg)) begin
    if (m_cfg.DATA_WIDTH == 32) begin
      cov_32b_normal = new();
      cov_32b_error  = new();
    end else if (m_cfg.DATA_WIDTH == 64) begin
      cov_64b_normal = new();
      cov_64b_error  = new();
    end else begin
      cov_32b_normal = new();
      cov_32b_error  = new();
    end
  end else begin
    cov_32b_normal = new();
    cov_32b_error  = new();
  end
endfunction

function void axi4lite_coverage_monitor::write(axi4lite_seq_item t);
  analysis_txn = t;

  if (m_cfg != null && m_cfg.DATA_WIDTH == 64) begin
    if (cov_64b_normal != null) cov_64b_normal.sample(t);
    if (cov_64b_error != null) cov_64b_error.sample(t);
  end else begin
    if (cov_32b_normal != null) cov_32b_normal.sample(t);
    if (cov_32b_error != null) cov_32b_error.sample(t);
  end
endfunction : write

function void axi4lite_coverage_monitor::report_phase(uvm_phase phase);
endfunction : report_phase
