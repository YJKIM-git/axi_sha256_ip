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
//   - Generates SHA-256 AXI4-Lite virtual-sequence stimulus for CSR verification.
//------------------------------------------------------------------------------

class sha256_axil_vseq extends sha256_base_vseq;
  `uvm_object_utils(sha256_axil_vseq)

  extern function new(string name = "sha256_axil_vseq");
  extern virtual task body();
endclass : sha256_axil_vseq

function sha256_axil_vseq::new(string name = "sha256_axil_vseq");
  super.new(name);
endfunction

task sha256_axil_vseq::body();
  axi4lite_protocol_cov_seq protocol_seq;
  axi4lite_err_inject_seq   err_seq;

  super.body();

  `uvm_info("VSEQ_AXIL", "Starting AXI4-Lite Coverage Sequences...", UVM_LOW)

  // [Test Plan: axil_handshake_delay, axil_wstrb, axil_prot]
  protocol_seq = axi4lite_protocol_cov_seq::type_id::create("protocol_seq");
  if (!protocol_seq.randomize()) `uvm_fatal("VSEQ_AXIL", "Failed to randomize protocol_seq")
  protocol_seq.start(axil_sqr);

  // [Test Plan: axil_err_resp, axil_unaligned]
  m_cfg.axi4lite_agent_cfg.disable_alignment_sva = 1;
  m_cfg.axi4lite_agent_cfg.disable_timeout_sva   = 1;
  if (m_cfg.axi4lite_agent_cfg.vif != null) begin
    m_cfg.axi4lite_agent_cfg.vif.disable_alignment_sva = 1;
    m_cfg.axi4lite_agent_cfg.vif.disable_timeout_sva   = 1;
  end

  err_seq = axi4lite_err_inject_seq::type_id::create("err_seq");
  if (!err_seq.randomize()) `uvm_fatal("VSEQ_AXIL", "Failed to randomize err_seq")
  err_seq.num_rand_err_trans = 50;
  err_seq.start(axil_sqr);

  m_cfg.axi4lite_agent_cfg.disable_alignment_sva = 0;
  m_cfg.axi4lite_agent_cfg.disable_timeout_sva   = 0;
  if (m_cfg.axi4lite_agent_cfg.vif != null) begin
    m_cfg.axi4lite_agent_cfg.vif.disable_alignment_sva = 0;
    m_cfg.axi4lite_agent_cfg.vif.disable_timeout_sva   = 0;
  end
  `uvm_info("VSEQ_AXIL", "Completed AXI4-Lite Coverage Sequences", UVM_LOW)
endtask
