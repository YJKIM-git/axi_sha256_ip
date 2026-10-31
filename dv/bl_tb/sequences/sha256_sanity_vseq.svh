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
//   - Generates the basic SHA-256 register, stream, digest, and interrupt sanity flow.
//------------------------------------------------------------------------------

class sha256_sanity_vseq extends sha256_base_vseq;
  `uvm_object_utils(sha256_sanity_vseq)

  extern function new(string name = "sha256_sanity_vseq");
  extern virtual task body();

endclass : sha256_sanity_vseq

function sha256_sanity_vseq::new(string name = "sha256_sanity_vseq");
  super.new(name);
endfunction

task sha256_sanity_vseq::body();
  axis_seq_item  axis_req;
  uvm_status_e   status;
  uvm_reg_data_t rdata;

  // [Test Plan: oa_lifecycle, oa_e2e_hash]
  super.body();

  if (m_cfg.axis_agent_cfg.drv_m_bfm.aresetn !== 1'b1) begin
    m_cfg.axis_agent_cfg.drv_m_bfm.wait_for_reset();
  end
  @(posedge m_cfg.axis_agent_cfg.drv_m_bfm.aclk);

  csr_rb.ID.read(status, rdata);
  if (rdata != 32'h41749591) begin
    `uvm_error("VSEQ", $sformatf("ID read mismatch. Expected: 0x41749591, Actual: 0x%08x", rdata))
  end

  csr_rb.CTRL.write(status, 32'h00000005);
  axis_req = axis_seq_item::type_id::create("axis_req");
  start_item(axis_req, -1, axis_sqr);

  if (!axis_req.randomize() with {tdata_q.size() == 1;}) begin
    `uvm_fatal("VSEQ", "axis_req randomize failed")
  end

  axis_req.tdata_q[0] = 32'h00636261;
  axis_req.tkeep_q[0] = 4'b0111;
  axis_req.tstrb_q[0] = 4'b0111;

  finish_item(axis_req);

  do begin
    csr_rb.STATUS.read(status, rdata);
  end while ((rdata & 32'h00000002) == 0);

  csr_rb.DIGEST_0.read(status, rdata);
  csr_rb.DIGEST_1.read(status, rdata);
  csr_rb.DIGEST_2.read(status, rdata);
  csr_rb.DIGEST_3.read(status, rdata);
  csr_rb.DIGEST_4.read(status, rdata);
  csr_rb.DIGEST_5.read(status, rdata);
  csr_rb.DIGEST_6.read(status, rdata);
  csr_rb.DIGEST_7.read(status, rdata);

  csr_rb.INTCLEAR.write(status, 32'h00000002);

endtask
