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
//   - Provides common configuration, register model, interrupt, and sequencer handles for SHA-256 virtual sequences.
//------------------------------------------------------------------------------

class sha256_base_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(sha256_base_vseq)

  sha256_env_config                  m_cfg;
  sha256_csr                         csr_rb;
  intr_util                          intr_proxy;
  axis_agent                         m_axis_agent;

  uvm_sequencer #(axi4lite_seq_item) axil_sqr;
  uvm_sequencer #(axis_seq_item)     axis_sqr;

  uvm_status_e                       status;
  uvm_reg_data_t                     rdata;

  extern function new(string name = "sha256_base_vseq");
  extern virtual task body();

endclass : sha256_base_vseq

function sha256_base_vseq::new(string name = "sha256_base_vseq");
  super.new(name);
endfunction

task sha256_base_vseq::body();
  if (m_cfg == null) begin
    `uvm_fatal(get_full_name(), "m_cfg is null")
  end

  csr_rb     = m_cfg.csr_rb;
  intr_proxy = m_cfg.m_intr_util;

  if (csr_rb == null) begin
    `uvm_fatal(get_full_name(), "csr_rb is null")
  end
endtask
