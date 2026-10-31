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
interface axi4lite_monitor_bfm (
    input              clk,
    input              reset_n,
    input logic [63:0] awaddr,
    input logic [ 2:0] awprot,
    input logic        awvalid,
    input logic        awready,
    input logic [63:0] wdata,
    input logic [ 7:0] wstrb,
    input logic        wvalid,
    input logic        wready,
    input logic [ 1:0] bresp,
    input logic        bvalid,
    input logic        bready,
    input logic [63:0] araddr,
    input logic [ 2:0] arprot,
    input logic        arvalid,
    input logic        arready,
    input logic [63:0] rdata,
    input logic [ 1:0] rresp,
    input logic        rvalid,
    input logic        rready
);

  import axi4lite_agent_pkg::*;

  axi4lite_monitor proxy;

  task automatic run();
    fork
      monitor_write();
      monitor_read();
    join
  endtask

  task automatic monitor_write();
    axi4lite_seq_item item;
    axi4lite_seq_item cloned_item;
    int aw_delay_cnt, w_delay_cnt, b_delay_cnt;

    forever begin
      item = axi4lite_seq_item::type_id::create("item");
      item.dir = axi4lite_seq_item::WRITE;
      aw_delay_cnt = 0;
      w_delay_cnt = 0;
      b_delay_cnt = 0;

      fork
        begin
          do begin
            @(posedge clk);
            if (!(awvalid && awready)) aw_delay_cnt++;
          end while (!(awvalid && awready));
          item.addr = awaddr;
          item.prot = awprot;
          item.aw_delay = aw_delay_cnt;
        end
        begin
          do begin
            @(posedge clk);
            if (!(wvalid && wready)) w_delay_cnt++;
          end while (!(wvalid && wready));
          item.wdata   = wdata;
          item.wstrb   = wstrb;
          item.w_delay = w_delay_cnt;
        end
      join

      do begin
        @(posedge clk);
        if (!(bvalid && bready)) b_delay_cnt++;
      end while (!(bvalid && bready));
      item.resp = bresp;
      item.b_delay = b_delay_cnt;

      $cast(cloned_item, item.clone());
      proxy.notify_transaction(cloned_item);
    end
  endtask

  task automatic monitor_read();
    axi4lite_seq_item item;
    axi4lite_seq_item cloned_item;
    int ar_delay_cnt, r_delay_cnt;

    forever begin
      item = axi4lite_seq_item::type_id::create("item");
      item.dir = axi4lite_seq_item::READ;
      ar_delay_cnt = 0;
      r_delay_cnt = 0;

      do begin
        @(posedge clk);
        if (!(arvalid && arready)) ar_delay_cnt++;
      end while (!(arvalid && arready));
      item.addr = araddr;
      item.prot = arprot;
      item.ar_delay = ar_delay_cnt;

      do begin
        @(posedge clk);
        if (!(rvalid && rready)) r_delay_cnt++;
      end while (!(rvalid && rready));
      item.rdata = rdata;
      item.resp = rresp;
      item.r_delay = r_delay_cnt;

      $cast(cloned_item, item.clone());
      proxy.notify_transaction(cloned_item);
    end
  endtask

endinterface
