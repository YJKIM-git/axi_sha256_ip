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
class axi4lite_seq_item extends uvm_sequence_item;

  typedef enum bit {
    WRITE = 1'b0,
    READ  = 1'b1
  } dir_e;

  `uvm_object_utils(axi4lite_seq_item)

  rand dir_e        dir;
  rand logic [63:0] addr;
  rand logic [63:0] wdata;
  rand logic [ 7:0] wstrb;
  rand logic [ 2:0] prot;

  rand int          aw_delay;
  rand int          w_delay;
  rand int          b_delay;
  rand int          ar_delay;
  rand int          r_delay;

  rand bit          force_unaligned_addr;
  rand bit          force_invalid_wstrb;
  rand bit          ignore_ready_timeout;

  logic      [63:0] rdata;
  logic      [ 1:0] resp;

  constraint delay_bound_c {
    aw_delay inside {[0 : 20]};
    w_delay inside {[0 : 20]};
    b_delay inside {[0 : 20]};
    ar_delay inside {[0 : 20]};
    r_delay inside {[0 : 20]};
  }

  constraint error_injection_default_c {
    soft force_unaligned_addr == 1'b0;
    soft force_invalid_wstrb == 1'b0;
    soft ignore_ready_timeout == 1'b0;
  }

  constraint error_injection_logic_c {
    if (force_unaligned_addr) {addr[1:0] != 2'b00;} else {addr[1:0] == 2'b00;}

    if (force_invalid_wstrb) {wstrb == 8'h00;}
  }

  extern function new(string name = "axi4lite_seq_item");
  extern function void do_copy(uvm_object rhs);
  extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);
  extern function string convert2string();
  extern function void do_print(uvm_printer printer);
  extern function void do_record(uvm_recorder recorder);

endclass : axi4lite_seq_item

function axi4lite_seq_item::new(string name = "axi4lite_seq_item");
  super.new(name);
endfunction

function void axi4lite_seq_item::do_copy(uvm_object rhs);
  axi4lite_seq_item rhs_;

  if (!$cast(rhs_, rhs)) begin
    `uvm_fatal("do_copy", "cast of rhs object failed")
  end
  super.do_copy(rhs);

  dir                  = rhs_.dir;
  addr                 = rhs_.addr;
  wdata                = rhs_.wdata;
  wstrb                = rhs_.wstrb;
  prot                 = rhs_.prot;
  aw_delay             = rhs_.aw_delay;
  w_delay              = rhs_.w_delay;
  b_delay              = rhs_.b_delay;
  ar_delay             = rhs_.ar_delay;
  r_delay              = rhs_.r_delay;
  force_unaligned_addr = rhs_.force_unaligned_addr;
  force_invalid_wstrb  = rhs_.force_invalid_wstrb;
  ignore_ready_timeout = rhs_.ignore_ready_timeout;
  rdata                = rhs_.rdata;
  resp                 = rhs_.resp;
endfunction : do_copy

function bit axi4lite_seq_item::do_compare(uvm_object rhs, uvm_comparer comparer);
  axi4lite_seq_item rhs_;

  if (!$cast(rhs_, rhs)) begin
    `uvm_error("do_compare", "cast of rhs object failed")
    return 0;
  end
  return super.do_compare(
      rhs, comparer
  ) && dir == rhs_.dir && addr == rhs_.addr && wdata == rhs_.wdata && wstrb == rhs_.wstrb &&
      prot == rhs_.prot && rdata == rhs_.rdata && resp == rhs_.resp && force_unaligned_addr ==
      rhs_.force_unaligned_addr && force_invalid_wstrb == rhs_.force_invalid_wstrb &&
      ignore_ready_timeout == rhs_.ignore_ready_timeout;
endfunction : do_compare

function string axi4lite_seq_item::convert2string();
  string s;

  $sformat(s, "%s\n", super.convert2string());
  $sformat(s, "%s\n dir\t%s\n addr\t%0h\n wdata\t%0h\n wstrb\t%0h\n prot\t%0b\n", s, dir.name(),
           addr, wdata, wstrb, prot);
  $sformat(s, "%s aw_dly\t%0d\n w_dly\t%0d\n b_dly\t%0d\n ar_dly\t%0d\n r_dly\t%0d\n", s, aw_delay,
           w_delay, b_delay, ar_delay, r_delay);
  $sformat(s, "%s err_unalign\t%0b\n err_wstrb\t%0b\n err_to\t%0b\n", s, force_unaligned_addr,
           force_invalid_wstrb, ignore_ready_timeout);
  $sformat(s, "%s rdata\t%0h\n resp\t%0h\n", s, rdata, resp);
  return s;
endfunction : convert2string

function void axi4lite_seq_item::do_print(uvm_printer printer);
  printer.m_string = convert2string();
endfunction : do_print

function void axi4lite_seq_item::do_record(uvm_recorder recorder);
  super.do_record(recorder);

  //`uvm_record_field("dir", dir)
  //`uvm_record_field("addr", addr)
  //`uvm_record_field("wdata", wdata)
  //`uvm_record_field("wstrb", wstrb)
  //`uvm_record_field("prot", prot)
  //`uvm_record_field("aw_delay", aw_delay)
  //`uvm_record_field("w_delay", w_delay)
  //`uvm_record_field("b_delay", b_delay)
  //`uvm_record_field("ar_delay", ar_delay)
  //`uvm_record_field("r_delay", r_delay)
  //`uvm_record_field("force_unaligned_addr", force_unaligned_addr)
  //`uvm_record_field("force_invalid_wstrb", force_invalid_wstrb)
  //`uvm_record_field("ignore_ready_timeout", ignore_ready_timeout)
  //`uvm_record_field("rdata", rdata)
  //`uvm_record_field("resp", resp)
endfunction : do_record
