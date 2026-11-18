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
//   - Generates SHA-256 CSR reset, access, busy, address-error, and protection scenarios.
//------------------------------------------------------------------------------

class sha256_csr_vseq extends sha256_base_vseq;
  `uvm_object_utils(sha256_csr_vseq)

  extern function new(string name = "sha256_csr_vseq");
  extern virtual task body();

  extern virtual task do_csr_reset();  // [Test Plan: csr_reset]
  extern virtual task do_csr_bit_bash();  // [Test Plan: csr_access]
  extern virtual task do_pulse_clear();  // [Test Plan: csr_pulse, csr_hw_update]
  extern virtual task do_addr_err_sweep();  // [Test Plan: csr_err_resp]
  extern virtual task do_busy_sweep();  // [Test Plan: csr_busy_prot]
  extern virtual task do_secure_prot();  // [Test Plan: csr_secure_prot]
  extern virtual task do_decouple_sync();  // [Test Plan: csr_ro_write_irq]
endclass : sha256_csr_vseq

function sha256_csr_vseq::new(string name = "sha256_csr_vseq");
  super.new(name);
endfunction

task sha256_csr_vseq::body();
  super.body();
  `uvm_info("VSEQ", "Starting CSR Verification Plan", UVM_LOW)
  do_csr_reset();
  do_csr_bit_bash();
  do_pulse_clear();
  do_addr_err_sweep();
  do_busy_sweep();
  do_secure_prot();
  do_decouple_sync();

  `uvm_info("VSEQ", "Completed CSR Verification Plan", UVM_LOW)
endtask

task sha256_csr_vseq::do_csr_reset();
  uvm_reg_hw_reset_seq reset_seq;

  `uvm_info("VSEQ", "[do_csr_reset] Checking initial reset values", UVM_LOW)

  reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
  reset_seq.model = csr_rb;
  reset_seq.start(null);
  if (intr_proxy.get_irq_level() != 1'b0) begin
    `uvm_error("VSEQ_CSR", "irq_o must remain low after reset")
  end
endtask

task sha256_csr_vseq::do_csr_bit_bash();
  uvm_reg_bit_bash_seq bitbash_seq;

  `uvm_info("VSEQ", "[do_csr_bit_bash] Checking RW/RO access policies", UVM_LOW)

  bitbash_seq = uvm_reg_bit_bash_seq::type_id::create("bitbash_seq");
  bitbash_seq.model = csr_rb;
  bitbash_seq.start(null);
endtask

task sha256_csr_vseq::do_pulse_clear();
  `uvm_info("VSEQ", "[do_pulse_clear] Checking auto-clear of pulse bits", UVM_LOW)

  csr_rb.CTRL.write(status, 32'h0000000C);
  csr_rb.CTRL.read(status, rdata);

  if ((rdata & 32'h0000000C) != 0) begin
    `uvm_error("VSEQ_CSR", $sformatf("Pulse clear failed. CTRL expected auto-clear, got 0x%08x",
                                     rdata))
  end

  csr_rb.INTCLEAR.write(status, 32'h00000006);
endtask

task sha256_csr_vseq::do_addr_err_sweep();
  axi4lite_seq_item req;
  axi4lite_seq_item::dir_e dirs[2] = '{axi4lite_seq_item::READ, axi4lite_seq_item::WRITE};
  bit [31:0] target_addrs[] = '{
      32'h00,
      32'h04,
      32'h08,
      32'h0C,
      32'h10,
      32'h14,
      32'h20,
      32'h24,
      32'h28,
      32'h2C,
      32'h30,
      32'h34,
      32'h38,
      32'h3C,
      32'h40,
      32'h80
  };
  bit [31:0] null_strb_addrs[2] = '{32'h04, 32'h80};

  `uvm_info("VSEQ", "[do_addr_err_sweep] Sweeping key addresses for error responses", UVM_LOW)

  foreach (target_addrs[i]) begin
    foreach (dirs[j]) begin
      req = axi4lite_seq_item::type_id::create("req");
      start_item(req, -1, axil_sqr);

      if (!req.randomize()) begin
        `uvm_fatal("VSEQ_CSR", "Randomize failed")
      end
      req.dir = dirs[j];
      req.addr = target_addrs[i];
      req.prot[1] = 1'b0;

      if (req.dir == axi4lite_seq_item::WRITE) begin
        req.wstrb = 4'hF;
        if (req.addr == 32'h04) req.wdata[2] = 1'b0;
      end

      finish_item(req);
    end
  end

  // [Code Coverage 1] target: Branch Coverage: wstrb_reg[0..3]==0, wstrb_reg[0..3]!=0
  foreach (null_strb_addrs[i]) begin
    req = axi4lite_seq_item::type_id::create("req");
    start_item(req, -1, axil_sqr);
    if (!req.randomize()) `uvm_fatal("VSEQ_CSR", "Randomize failed")
    req.dir     = axi4lite_seq_item::WRITE;
    req.addr    = null_strb_addrs[i];
    req.prot[1] = 1'b0;
    req.wstrb   = 4'h0;
    finish_item(req);
  end

  // [Code Coverage 2] target: toggle Coverage: awaddr_reg[1], araddr_reg[1]
  foreach (dirs[j]) begin
    req = axi4lite_seq_item::type_id::create("req");
    start_item(req, -1, axil_sqr);
    if (!req.randomize()) `uvm_fatal("VSEQ_CSR", "Randomize failed")
    req.dir                  = dirs[j];
    req.force_unaligned_addr = 1'b1;
    req.addr                 = 32'h02;
    req.prot[1]              = 1'b0;
    req.wstrb                = 4'hF;
    finish_item(req);

    req = axi4lite_seq_item::type_id::create("req");
    start_item(req, -1, axil_sqr);
    if (!req.randomize()) `uvm_fatal("VSEQ_CSR", "Randomize failed")
    req.dir     = dirs[j];
    req.addr    = 32'h00;
    req.prot[1] = 1'b0;
    req.wstrb   = 4'hF;
    finish_item(req);
  end
endtask

task sha256_csr_vseq::do_busy_sweep();
  axi4lite_seq_item req;
  axi4lite_seq_item::dir_e dirs[2] = '{axi4lite_seq_item::READ, axi4lite_seq_item::WRITE};
  bit [31:0] target_addrs[] = '{32'h00, 32'h04, 32'h08, 32'h0C, 32'h20, 32'h40, 32'h80};
  bit prots[2] = '{1'b0, 1'b1};
  bit [31:0] busy_ctrl_wdatas[] = '{
      32'h00000001,  // Same value as active CTRL (EN=1, IRQ_EN=0) -> Must still return SLVERR!
      32'h00000003,  // EN=1, IRQ_EN=1
      32'h00000000,  // EN=0, IRQ_EN=0
      32'h00000008,  // SOFT_RESET=1, EN=0, IRQ_EN=0
      32'h0000000B,  // SOFT_RESET=1, EN=1, IRQ_EN=1
      32'h0000000A  // SOFT_RESET=1, EN=0, IRQ_EN=1
  };
  uvm_status_e status;
  uvm_reg_data_t rdata;

  `uvm_info("VSEQ", "[do_busy_sweep] Sweeping addresses while core is BUSY", UVM_LOW)

  foreach (target_addrs[i]) begin
    foreach (dirs[j]) begin
      foreach (prots[k]) begin
        bit [31:0] local_addr = target_addrs[i];
        axi4lite_seq_item::dir_e local_dir = dirs[j];
        bit local_prot = prots[k];

        csr_rb.CTRL.write(status, 32'h00000009);
        csr_rb.CTRL.write(status, 32'h00000005);
        csr_rb.STATUS.read(status, rdata);

        req = axi4lite_seq_item::type_id::create("req");
        start_item(req, -1, axil_sqr);

        if (!req.randomize()) begin
          `uvm_fatal("VSEQ_CSR", "Randomize failed")
        end

        req.dir = local_dir;
        req.addr = local_addr;
        req.prot[1] = local_prot;

        if (local_dir == axi4lite_seq_item::WRITE) begin
          req.wstrb = 4'hF;
          req.wdata[3] = 1'b0;
          req.wdata[2] = 1'b1;
        end

        finish_item(req);
      end
    end
  end

  foreach (busy_ctrl_wdatas[m]) begin
    csr_rb.CTRL.write(status, 32'h00000009);
    csr_rb.CTRL.write(status, 32'h00000005);
    csr_rb.STATUS.read(status, rdata);

    req = axi4lite_seq_item::type_id::create("req");
    start_item(req, -1, axil_sqr);
    if (!req.randomize()) `uvm_fatal("VSEQ_CSR", "Randomize failed")
    req.dir     = axi4lite_seq_item::WRITE;
    req.addr    = 32'h04;
    req.prot[1] = 1'b0;
    req.wstrb   = 4'hF;
    req.wdata   = busy_ctrl_wdatas[m];
    finish_item(req);
  end

  csr_rb.CTRL.write(status, 32'h00000009);
  csr_rb.CTRL.write(status, 32'h00000005);
  csr_rb.STATUS.read(status, rdata);

  req = axi4lite_seq_item::type_id::create("req");
  start_item(req, -1, axil_sqr);
  if (!req.randomize()) `uvm_fatal("VSEQ_CSR", "Randomize failed")
  req.dir     = axi4lite_seq_item::WRITE;
  req.addr    = 32'h04;
  req.prot[1] = 1'b0;
  req.wstrb   = 4'b1110;
  req.wdata   = 32'h00000008;
  finish_item(req);

  csr_rb.CTRL.write(status, 32'h00000009);
  csr_rb.STATUS.read(status, rdata);
endtask

task sha256_csr_vseq::do_secure_prot();
  axi4lite_seq_item req;
  axi4lite_seq_item::dir_e dirs[2] = '{axi4lite_seq_item::READ, axi4lite_seq_item::WRITE};
  bit [31:0] target_addrs[] = '{32'h00, 32'h04, 32'h08, 32'h0C, 32'h20, 32'h40, 32'h80};

  `uvm_info("VSEQ", "[do_secure_prot] Sweeping Non-secure accesses", UVM_LOW)

  foreach (target_addrs[i]) begin
    foreach (dirs[j]) begin
      req = axi4lite_seq_item::type_id::create("req");
      start_item(req, -1, axil_sqr);

      if (!req.randomize()) begin
        `uvm_fatal("VSEQ_CSR", "Randomize failed")
      end
      req.dir     = dirs[j];
      req.addr    = target_addrs[i];
      req.prot[1] = 1'b1;

      finish_item(req);
    end
  end
endtask

task sha256_csr_vseq::do_decouple_sync();
  axi4lite_seq_item req;
  uvm_reg_data_t status_data;

  `uvm_info("VSEQ", "[do_decouple_sync] Checking RO write error isolation", UVM_LOW)

  csr_rb.CTRL.write(status, 32'h00000003);
  csr_rb.INTCLEAR.write(status, 32'h00000006);
  csr_rb.STATUS.read(status, status_data);

  if (status_data[2:1] != 2'b00) begin
    `uvm_error("VSEQ_CSR", $sformatf("STATUS must be clear before RO write, got 0x%08x",
                                     status_data))
  end

  req = axi4lite_seq_item::type_id::create("ro_write_req");
  start_item(req, -1, axil_sqr);
  if (!req.randomize()) begin
    `uvm_fatal("VSEQ_CSR", "Randomize failed")
  end
  req.dir     = axi4lite_seq_item::WRITE;
  req.addr    = 32'h00;  // ID: read-only
  req.prot[1] = 1'b0;
  req.wstrb   = 4'hF;
  req.wdata   = 32'h00000000;
  finish_item(req);

  csr_rb.STATUS.read(status, status_data);
  if (status_data[2] != 1'b0) begin
    `uvm_error("VSEQ_CSR", $sformatf(
                               "STATUS.ERR_PRT must remain 0 after RO write, got STATUS=0x%08x",
                               status_data))
  end

  if (intr_proxy.get_irq_level() != 1'b0) begin
    `uvm_error("VSEQ_CSR", "irq_o must remain low after an isolated RO write")
  end
endtask
