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
//   - Defines SHA-256 CSR protocol, response, protection, and busy-state coverage.
//------------------------------------------------------------------------------

typedef enum {
  CSR_CTRL,
  CSR_STATUS,
  CSR_INTCLEAR,
  CSR_DIGEST,
  CSR_OTHER
} csr_reg_e;

class sha256_csr_coverage extends uvm_subscriber #(axi4lite_seq_item);
  `uvm_component_utils(sha256_csr_coverage)

  sha256_csr csr_rb;
  bit        last_valid_busy = 0;

  covergroup cg_csr_protocol with function sample (
      csr_reg_e decoded_reg, axi4lite_seq_item t, bit is_busy
  );
    option.per_instance = 1;

    cp_addr: coverpoint decoded_reg {
      bins ctrl = {CSR_CTRL};
      bins status = {CSR_STATUS};
      bins intclear = {CSR_INTCLEAR};
      bins digest = {CSR_DIGEST};
      bins others = {CSR_OTHER};
    }

    cp_dir: coverpoint t.dir {
      bins write = {axi4lite_seq_item::WRITE}; bins read = {axi4lite_seq_item::READ};
    }

    cp_resp: coverpoint t.resp {bins okay = {2'b00}; bins slverr = {2'b10}; bins decerr = {2'b11};}

    cp_prot: coverpoint t.prot[1] {bins secure = {1'b0}; bins non_secure = {1'b1};}

    cp_busy: coverpoint is_busy {bins idle = {0}; bins busy = {1};}

    // [Test Plan: csr_wo_err] Exclude unreachable response combinations enforced by hardware firewall
    cr_wo_err: cross cp_addr, cp_dir, cp_resp{
      bins hit = binsof (cp_addr.intclear) && binsof (cp_dir.read) && binsof (cp_resp.decerr);

      ignore_bins no_decerr_on_mapped = binsof(cp_resp.decerr) && 
          (binsof(cp_addr.ctrl) || binsof(cp_addr.status) || binsof(cp_addr.digest) || (binsof(cp_addr.intclear) && binsof(cp_dir.write)));
      ignore_bins ro_write_success = binsof(cp_dir.write) && binsof(cp_resp.okay) && 
          (binsof(cp_addr.status) || binsof(cp_addr.digest));
      ignore_bins wo_read_success = binsof(cp_addr.intclear) && binsof(cp_dir.read) && 
          (binsof(cp_resp.okay) || binsof(cp_resp.slverr));
    }

    // [Test Plan: csr_busy_prot] Exclude unreachable combinations during BUSY state
    cr_busy_prot: cross cp_addr, cp_dir, cp_busy, cp_resp{
      bins hit = binsof(cp_addr.ctrl) && binsof(cp_dir.write) && binsof(cp_busy.busy) && binsof(cp_resp.slverr);

      ignore_bins no_decerr_on_mapped = binsof(cp_resp.decerr) && 
          (binsof(cp_addr.ctrl) || binsof(cp_addr.status) || binsof(cp_addr.digest) || (binsof(cp_addr.intclear) && binsof(cp_dir.write)));
      ignore_bins ro_write_success = binsof(cp_dir.write) && binsof(cp_resp.okay) && 
          (binsof(cp_addr.status) || binsof(cp_addr.digest));
      ignore_bins wo_read_success = binsof(cp_addr.intclear) && binsof(cp_dir.read) && 
          (binsof(cp_resp.okay) || binsof(cp_resp.slverr));
      ignore_bins others_write_busy_okay = binsof(cp_addr.others) && binsof(cp_dir.write) && binsof(cp_busy.busy) && binsof(cp_resp.okay);
    }

    // [Test Plan: csr_secure_prot] Non-secure accesses always return SLVERR
    cr_secure_prot: cross cp_prot, cp_resp{
      bins hit = binsof (cp_prot.non_secure) && binsof (cp_resp.slverr);

      ignore_bins impossible = binsof(cp_prot.non_secure) && 
                               (binsof(cp_resp.okay) || binsof(cp_resp.decerr));
    }
  endgroup

  covergroup cg_hw_update with function sample (bit done_val);
    option.per_instance = 1;
    cp_done: coverpoint done_val {bins trans_01 = (0 => 1);}
  endgroup

  extern function new(string name = "sha256_csr_coverage", uvm_component parent = null);
  extern function void write(axi4lite_seq_item t);
endclass : sha256_csr_coverage

function sha256_csr_coverage::new(string name = "sha256_csr_coverage", uvm_component parent = null);
  super.new(name, parent);
  cg_csr_protocol = new();
  cg_hw_update    = new();
endfunction

function void sha256_csr_coverage::write(axi4lite_seq_item t);
  bit       current_busy = 0;
  bit       current_done = 0;
  csr_reg_e decoded_reg = CSR_OTHER;
  uvm_reg   target_reg;
  string    reg_name;

  if (t == null) return;

  if (csr_rb != null) begin
    // Cache STATUS.BUSY mirror only on OKAY response to prevent SLVERR read-masking (0x0) corruption
    if (t.resp == 2'b00) begin
      last_valid_busy = csr_rb.STATUS.BUSY.get_mirrored_value();
      current_done    = csr_rb.STATUS.DONE.get_mirrored_value();
      cg_hw_update.sample(current_done);
    end
    current_busy = last_valid_busy;

    target_reg   = csr_rb.default_map.get_reg_by_offset(t.addr);

    if (target_reg != null) begin
      if (target_reg == csr_rb.CTRL) begin
        decoded_reg = CSR_CTRL;
      end else if (target_reg == csr_rb.STATUS) begin
        decoded_reg = CSR_STATUS;
      end else if (target_reg == csr_rb.INTCLEAR) begin
        decoded_reg = CSR_INTCLEAR;
      end else begin
        reg_name = target_reg.get_name();
        if (reg_name.len() >= 8 && reg_name.substr(0, 6) == "DIGEST_") begin
          decoded_reg = CSR_DIGEST;
        end
      end
    end
  end

  cg_csr_protocol.sample(decoded_reg, t, current_busy);
endfunction
