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
//   - Provides the common AXI4-Stream sequence base and configuration propagation used by SHA-256 stimulus sequences.
//------------------------------------------------------------------------------

class axis_base_seq extends uvm_sequence #(axis_seq_item);

  `uvm_object_utils(axis_base_seq)

  axis_agent_config cfg;

  extern function new(string name = "axis_base_seq");
  extern task pre_body();
  extern function void configure_request(ref axis_seq_item item);
  extern task post_body();

endclass : axis_base_seq

function axis_base_seq::new(string name = "axis_base_seq");
  super.new(name);
endfunction

task axis_base_seq::pre_body();
  if (starting_phase != null) begin
    starting_phase.raise_objection(this);
  end

  cfg = axis_agent_config::get_config(get_sequencer());
endtask

function void axis_base_seq::configure_request(ref axis_seq_item item);
  cfg.apply_to_item(item);
endfunction

task axis_base_seq::post_body();
  if (starting_phase != null) begin
    starting_phase.drop_objection(this);
  end
endtask
