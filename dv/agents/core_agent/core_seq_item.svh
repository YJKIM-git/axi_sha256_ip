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
//   - Defines the SHA-256 core sequence item and observed transaction state.
//------------------------------------------------------------------------------

class core_seq_item extends uvm_sequence_item;

  rand logic [511:0] block_i;
  rand logic [255:0] state_in_i;

  logic [255:0] state_out_o;
  int latency;

  bit is_aborted;
  int aborted_cycle;
  logic [5:0] aborted_round;
  logic first_block;

  `uvm_object_utils_begin(core_seq_item)
    `uvm_field_int(block_i, UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(state_in_i, UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(state_out_o, UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(latency, UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(is_aborted, UVM_DEFAULT | UVM_BIN)
    `uvm_field_int(aborted_cycle, UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(aborted_round, UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(first_block, UVM_DEFAULT | UVM_BIN)
  `uvm_object_utils_end

  extern function new(string name = "core_seq_item");
endclass : core_seq_item

function core_seq_item::new(string name = "core_seq_item");
super.new(name);
is_aborted = 0;
endfunction
