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

//
// Class Description:
//
//
interface axi4lite_driver_bfm (
    input logic clk,
    input logic reset_n,

    output logic [63:0] awaddr,
    output logic [ 2:0] awprot,
    output logic        awvalid,
    input  logic        awready,

    output logic [63:0] wdata,
    output logic [ 7:0] wstrb,
    output logic        wvalid,
    input  logic        wready,

    input  logic [1:0] bresp,
    input  logic       bvalid,
    output logic       bready,

    output logic [63:0] araddr,
    output logic [ 2:0] arprot,
    output logic        arvalid,
    input  logic        arready,

    input  logic [63:0] rdata,
    input  logic [ 1:0] rresp,
    input  logic        rvalid,
    output logic        rready
);

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import axi4lite_agent_pkg::*;

  axi4lite_agent_config m_cfg;

  function automatic void clear_sigs();
    awvalid <= 0;
    awaddr  <= 0;
    awprot  <= 0;
    wvalid  <= 0;
    wdata   <= 0;
    wstrb   <= 0;
    bready  <= 0;
    arvalid <= 0;
    araddr  <= 0;
    arprot  <= 0;
    rready  <= 0;
  endfunction

  task automatic wait_for_reset();
    wait (!reset_n);
    clear_sigs();
    wait (reset_n);
    repeat (2) @(posedge clk);
  endtask

  task automatic drive_write(axi4lite_seq_item req);
    int wait_cycles;

    if (!is_valid_address(req.addr, req.force_unaligned_addr)) begin
      `uvm_error("DRV_BFM", $sformatf("Write address %0h is invalid or out of bounds", req.addr))
      req.resp = 2'b11;
      return;
    end

    fork
      begin
        wait_cycles = 0;
        repeat (req.aw_delay) @(posedge clk);
        awaddr  <= req.force_unaligned_addr ? (req.addr | 64'h1) : req.addr;
        awprot  <= req.prot;
        awvalid <= 1;
        do begin
          @(posedge clk);
          wait_cycles++;
          if (!req.ignore_ready_timeout && wait_cycles > 100) begin
            `uvm_error("DRV_BFM", "awready timeout occurred")
            break;
          end
        end while (!awready);
        awvalid <= 0;
      end
      begin
        wait_cycles = 0;
        repeat (req.w_delay) @(posedge clk);
        wdata  <= req.wdata;
        wstrb  <= req.force_invalid_wstrb ? ~req.wstrb : req.wstrb;
        wvalid <= 1;
        do begin
          @(posedge clk);
          wait_cycles++;
          if (!req.ignore_ready_timeout && wait_cycles > 100) begin
            `uvm_error("DRV_BFM", "wready timeout occurred")
            break;
          end
        end while (!wready);
        wvalid <= 0;
      end
    join

    wait_cycles = 0;
    repeat (req.b_delay) @(posedge clk);
    bready <= 1;
    do begin
      @(posedge clk);
      wait_cycles++;
      if (!req.ignore_ready_timeout && wait_cycles > 100) begin
        `uvm_error("DRV_BFM", "bvalid timeout occurred")
        break;
      end
    end while (!bvalid);
    req.resp = bresp;
    bready <= 0;
  endtask

  task automatic drive_read(axi4lite_seq_item req);
    int wait_cycles;

    if (!is_valid_address(req.addr, req.force_unaligned_addr)) begin
      `uvm_error("DRV_BFM", $sformatf("Read address %0h is invalid or out of bounds", req.addr))
      req.resp = 2'b11;
      return;
    end

    wait_cycles = 0;
    repeat (req.ar_delay) @(posedge clk);
    araddr  <= req.force_unaligned_addr ? (req.addr | 64'h1) : req.addr;
    arprot  <= req.prot;
    arvalid <= 1;
    do begin
      @(posedge clk);
      wait_cycles++;
      if (!req.ignore_ready_timeout && wait_cycles > 100) begin
        `uvm_error("DRV_BFM", "arready timeout occurred")
        break;
      end
    end while (!arready);
    arvalid <= 0;

    wait_cycles = 0;
    repeat (req.r_delay) @(posedge clk);
    rready <= 1;
    do begin
      @(posedge clk);
      wait_cycles++;
      if (!req.ignore_ready_timeout && wait_cycles > 100) begin
        `uvm_error("DRV_BFM", "rvalid timeout occurred")
        break;
      end
    end while (!rvalid);
    req.rdata = rdata;
    req.resp  = rresp;
    rready <= 0;
  endtask

  function automatic bit is_valid_address(logic [63:0] address, bit force_unaligned);
    if (m_cfg.ADDR_WIDTH < 64 && (address >> m_cfg.ADDR_WIDTH) != 0) return 0;
    if (force_unaligned) return 1;

    if (m_cfg.DATA_WIDTH == 32 && address[1:0] != 2'b00) return 0;
    if (m_cfg.DATA_WIDTH == 64 && address[2:0] != 3'b000) return 0;

    return 1;
  endfunction

endinterface : axi4lite_driver_bfm
