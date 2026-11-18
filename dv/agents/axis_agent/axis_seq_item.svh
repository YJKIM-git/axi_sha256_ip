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
//   - Defines the AXI4-Stream packet transaction object, beat queues, masks, delays, and error controls.
//------------------------------------------------------------------------------

`include "uvm_macros.svh"
import uvm_pkg::*;

class axis_seq_item extends uvm_sequence_item;

  `uvm_object_utils(axis_seq_item)

  localparam int DataWidth = 1024;
  localparam int UserWidth = 1024;
  localparam int IdWidth   = 32;
  localparam int DestWidth = 32;
  localparam int StrbWidth = (DataWidth + 7) / 8;

  typedef enum {
    OK,
    INCOMPLETE,
    PROTOCOL_ERR
  } status_e;
  status_e status = OK;

  rand logic [DataWidth-1:0] tdata_q[$];
  rand logic [StrbWidth-1:0] tstrb_q[$];
  rand logic [StrbWidth-1:0] tkeep_q[$];
  rand logic [UserWidth-1:0] tuser_q[$];

  rand logic [IdWidth-1:0] tid;
  rand logic [DestWidth-1:0] tdest;

  rand int valid_delay_q[$];
  rand int ready_delay_q[$];

  rand bit force_tkeep_error;
  rand bit drop_tlast;
  rand bit force_tvalid_drop;
  rand bit err_mid_pkt_tid_change;
  rand bit err_mid_pkt_tdest_change;

  int active_data_width = DataWidth;
  int active_user_width = UserWidth;
  int active_id_max = 7;
  int active_dest_max = 7;
  logic [StrbWidth-1:0] active_byte_mask;

  int packet_id;
  time start_time;
  time end_time;

  constraint queue_size_c {
    tdata_q.size() > 0;
    tstrb_q.size() == tdata_q.size();
    tkeep_q.size() == tdata_q.size();
    tuser_q.size() == tdata_q.size();
    valid_delay_q.size() == tdata_q.size();
    ready_delay_q.size() == tdata_q.size();
  }

  constraint delay_c {
    foreach (valid_delay_q[i]) {valid_delay_q[i] inside {[0 : 10]};}
    foreach (ready_delay_q[i]) {ready_delay_q[i] inside {[0 : 10]};}
  }

  constraint error_default_c {
    soft force_tkeep_error == 1'b0;
    soft drop_tlast == 1'b0;
    soft force_tvalid_drop == 1'b0;
    soft err_mid_pkt_tid_change == 1'b0;
    soft err_mid_pkt_tdest_change == 1'b0;
  }

  constraint queue_size_limit_c {soft tdata_q.size() inside {[1 : 64]};}

  constraint active_id_dest_pool_c {
    tid inside {[0 : active_id_max]};
    tdest inside {[0 : active_dest_max]};
  }

  constraint tkeep_tstrb_rule_c {
    if (!force_tkeep_error) {
      foreach (tkeep_q[i]) {soft tkeep_q[i] == active_byte_mask;}
      foreach (tstrb_q[i]) {soft tstrb_q[i] == active_byte_mask;}
    }
  }

  extern function new(string name = "axis_seq_item");
  extern function void pre_randomize();
  extern function void post_randomize();
  extern function void do_copy(uvm_object rhs);
  extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);
  extern function string convert2string();
  extern function void do_print(uvm_printer printer);
  extern function void do_record(uvm_recorder recorder);

endclass : axis_seq_item

function axis_seq_item::new(string name = "axis_seq_item");
  super.new(name);
  active_byte_mask = '0;
  for (int b = 0; b < ((active_data_width + 7) / 8); b++) begin
    active_byte_mask[b] = 1'b1;
  end
endfunction

function void axis_seq_item::pre_randomize();
  active_byte_mask = '0;
  for (int b = 0; b < ((active_data_width + 7) / 8); b++) begin
    active_byte_mask[b] = 1'b1;
  end
endfunction

function void axis_seq_item::post_randomize();
  logic [DataWidth-1:0] data_mask;
  logic [UserWidth-1:0] user_mask;

  data_mask = '0;
  user_mask = '0;

  for (int b = 0; b < active_data_width; b++) begin
    data_mask[b] = 1'b1;
  end

  for (int b = 0; b < active_user_width; b++) begin
    user_mask[b] = 1'b1;
  end

  foreach (tdata_q[i]) begin
    tdata_q[i] &= data_mask;
    tuser_q[i] &= user_mask;
    tkeep_q[i] &= active_byte_mask;
    tstrb_q[i] &= active_byte_mask;
  end
endfunction

function void axis_seq_item::do_copy(uvm_object rhs);
  axis_seq_item rhs_;

  if (!$cast(rhs_, rhs)) begin
    $fatal(1, "axis_seq_item.do_copy cast of rhs object failed");
  end
  super.do_copy(rhs);

  tdata_q = rhs_.tdata_q;
  tstrb_q = rhs_.tstrb_q;
  tkeep_q = rhs_.tkeep_q;
  tuser_q = rhs_.tuser_q;
  tid = rhs_.tid;
  tdest = rhs_.tdest;
  valid_delay_q = rhs_.valid_delay_q;
  ready_delay_q = rhs_.ready_delay_q;
  force_tkeep_error = rhs_.force_tkeep_error;
  drop_tlast = rhs_.drop_tlast;
  force_tvalid_drop = rhs_.force_tvalid_drop;
  err_mid_pkt_tid_change = rhs_.err_mid_pkt_tid_change;
  err_mid_pkt_tdest_change = rhs_.err_mid_pkt_tdest_change;
  packet_id = rhs_.packet_id;
  start_time = rhs_.start_time;
  end_time = rhs_.end_time;
  status = rhs_.status;
  active_data_width = rhs_.active_data_width;
  active_user_width = rhs_.active_user_width;
  active_id_max = rhs_.active_id_max;
  active_dest_max = rhs_.active_dest_max;
  active_byte_mask = rhs_.active_byte_mask;
endfunction

function bit axis_seq_item::do_compare(uvm_object rhs, uvm_comparer comparer);
  axis_seq_item rhs_;
  bit result = 1'b1;

  if (!$cast(rhs_, rhs)) begin
    $error("axis_seq_item.do_compare cast of rhs object failed");
    return 0;
  end

  result &= super.do_compare(rhs, comparer);
  result &= (tdata_q == rhs_.tdata_q);
  result &= (tstrb_q == rhs_.tstrb_q);
  result &= (tkeep_q == rhs_.tkeep_q);
  result &= (tuser_q == rhs_.tuser_q);
  result &= (tid == rhs_.tid);
  result &= (tdest == rhs_.tdest);
  result &= (force_tkeep_error == rhs_.force_tkeep_error);
  result &= (drop_tlast == rhs_.drop_tlast);
  result &= (force_tvalid_drop == rhs_.force_tvalid_drop);
  result &= (err_mid_pkt_tid_change == rhs_.err_mid_pkt_tid_change);
  result &= (err_mid_pkt_tdest_change == rhs_.err_mid_pkt_tdest_change);
  result &= (active_data_width == rhs_.active_data_width);
  result &= (active_user_width == rhs_.active_user_width);
  result &= (active_id_max == rhs_.active_id_max);
  result &= (active_dest_max == rhs_.active_dest_max);
  result &= (active_byte_mask == rhs_.active_byte_mask);
  result &= (status == rhs_.status);

  return result;
endfunction

function string axis_seq_item::convert2string();
  string s;

  $sformat(s, "%s\n", super.convert2string());
  $sformat(s, "%s Packet Size\t%0d\n", s, tdata_q.size());
  $sformat(s, "%s Packet ID\t%0d\n", s, packet_id);
  $sformat(s, "%s Status\t%s\n", s, status.name());
  $sformat(s, "%s TID\t%0h\n TDEST\t%0h\n", s, tid, tdest);
  $sformat(s, "%s err_tkeep\t%0b\n err_drop_tlast\t%0b\n err_tvalid_drop\t%0b\n", s,
           force_tkeep_error, drop_tlast, force_tvalid_drop);
  $sformat(s, "%s Start Time\t%0t\n End Time\t%0t\n", s, start_time, end_time);
  return s;
endfunction

function void axis_seq_item::do_print(uvm_printer printer);
  printer.m_string = convert2string();
endfunction

function void axis_seq_item::do_record(uvm_recorder recorder);
  super.do_record(recorder);
endfunction
