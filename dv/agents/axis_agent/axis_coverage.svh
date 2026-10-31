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
//   - Defines AXI4-Stream handshake, packet, qualifier, routing, sideband, and reset coverage for the SHA-256 environment.
//------------------------------------------------------------------------------

covergroup cg_routing_matrix_type(
    int max_id, int max_dest
) with function sample (
    bit [31:0] tid, bit [31:0] tdest
);
  option.per_instance = 1;

  cp_tid: coverpoint tid {bins active_ids[] = {[0 : max_id]};}
  cp_tdest: coverpoint tdest {bins active_dests[] = {[0 : max_dest]};}
// [WV-AXIS-13] Cross coverage omitted because DUT does not use TID/TDEST pins
endgroup

covergroup cg_routing_change_type(
    bit can_id_change, bit can_dest_change
) with function sample (
    bit tlast, bit id_changed, bit dest_changed
);
  option.per_instance = 1;
  option.weight = 0;  // [WV-AXIS-14] DUT does not use TID/TDEST pins

  cp_tlast: coverpoint tlast {bins at_last = {1};}
  cp_id_change: coverpoint id_changed {bins changes[] = {[0 : can_id_change]};}
  cp_dest_change: coverpoint dest_changed {bins changes[] = {[0 : can_dest_change]};}
  cr_change_at_last: cross cp_tlast, cp_id_change, cp_dest_change;
endgroup

typedef enum {
  KEEP_ALL_1,
  KEEP_PARTIAL,
  KEEP_ALL_0
} keep_strb_state_e;

typedef enum {
  USER_ALL_0,
  USER_MIXED
} user_state_e;

typedef enum {
  DATA_ALL_0,
  DATA_ALL_1,
  DATA_TOGGLE
} data_pattern_e;

typedef enum {
  READY_STALL_SHORT,
  READY_STALL_LONG
} ready_stall_length_e;

covergroup cg_data_pattern_type() with function sample (data_pattern_e pattern, bit tlast);
  option.per_instance = 1;

  cp_tdata_pattern: coverpoint pattern {
    bins all_0 = {DATA_ALL_0}; bins all_1 = {DATA_ALL_1}; bins toggle = {DATA_TOGGLE};
  }
  cp_tlast: coverpoint tlast {bins not_last = {0}; bins last = {1};}
  cr_pattern_tlast: cross cp_tdata_pattern, cp_tlast;
endgroup

// [WAIVER] cg_null_transfer is already declared as a static covergroup inside the class
// covergroup cg_null_transfer_type() with function sample (
//     bit tkeep_all_zero, bit tlast
// );
//   option.per_instance = 1;
//
//   cp_tkeep_all_zero: coverpoint tkeep_all_zero {
//     bins normal = {0};
//     bins null_transfer = {1};
//   }
//   cp_tlast: coverpoint tlast {bins not_last = {0}; bins last = {1};}
//   cr_null_tlast: cross cp_tkeep_all_zero, cp_tlast;
// endgroup

covergroup cg_backpressure_corner_type() with function sample (
    bit stall_near_tlast, ready_stall_length_e stall_length
);
  option.per_instance = 1;

  cp_stall_near_tlast: coverpoint stall_near_tlast {
    bins away_from_tlast = {0}; bins near_tlast = {1};
  }
  cp_ready_stall_length: coverpoint stall_length {
    // [WV-AXIS-10] DUT core backpressure is fixed at 69 cycles (READY_STALL_LONG)
    ignore_bins short = {READY_STALL_SHORT};
    bins long = {READY_STALL_LONG};
  }
  cr_stall_tlast: cross cp_stall_near_tlast, cp_ready_stall_length;
endgroup

function automatic bit is_toggle_pattern(logic [1023:0] data, int width);
  if (width < 2) return 0;
  for (int b = 1; b < width; b++) begin
    if (data[b] == data[b-1]) return 0;
  end
  return 1;
endfunction

covergroup cg_byte_qualifier_type_partial() with function sample (
    bit tlast, keep_strb_state_e keep_state
);
  option.per_instance = 1;

  cp_tkeep_state: coverpoint keep_state {
    bins all_1 = {KEEP_ALL_1};
    bins partial = {KEEP_PARTIAL};
    ignore_bins ignore_all_0 = {KEEP_ALL_0};
  }
  cp_tlast: coverpoint tlast {bins tlast_0 = {0}; bins tlast_1 = {1};}

  // [WV-AXIS-11] Conditional coverpoint excluding mid-packet partial TKEEP (TLAST=0 && KEEP_PARTIAL)
  cp_tlast_tkeep_cross: coverpoint (
      (tlast == 1'b0 && keep_state == KEEP_ALL_1) ? 0 :
      (tlast == 1'b1 && keep_state == KEEP_ALL_1) ? 1 :
      (tlast == 1'b1 && keep_state == KEEP_PARTIAL) ? 2 : 3
  ) {
    bins tlast_0_all_1 = {0}; bins tlast_1_all_1 = {1}; bins tlast_1_partial = {2};
  }
endgroup

covergroup cg_byte_qualifier_type_no_partial() with function sample (
    bit tlast, keep_strb_state_e keep_state
);
  option.per_instance = 1;

  cp_tkeep_state: coverpoint keep_state {
    bins all_1 = {KEEP_ALL_1}; ignore_bins ignore_all_0 = {KEEP_ALL_0};
  }
  cp_tlast: coverpoint tlast {bins tlast_0 = {0}; bins tlast_1 = {1};}
  cr_tlast_tkeep: cross cp_tlast, cp_tkeep_state;
endgroup

covergroup cg_tkeep_tstrb_type_partial() with function sample (
    keep_strb_state_e keep_state, keep_strb_state_e strb_state
);
  option.per_instance = 1;

  cp_tkeep: coverpoint keep_state {
    bins all_1 = {KEEP_ALL_1};
    bins partial = {KEEP_PARTIAL};
    ignore_bins ignore_all_0 = {KEEP_ALL_0};
  }
  cp_tstrb: coverpoint strb_state {
    bins all_1 = {KEEP_ALL_1};
    bins partial = {KEEP_PARTIAL};
    ignore_bins ignore_all_0 = {KEEP_ALL_0};
  }

  // [WV-AXIS-12] DUT does not use TSTRB; verify matched TKEEP/TSTRB states only
  cp_keep_strb_cross: coverpoint (
      (keep_state == KEEP_ALL_1 && strb_state == KEEP_ALL_1) ? 0 :
      (keep_state == KEEP_PARTIAL && strb_state == KEEP_PARTIAL) ? 1 : 2
  ) {
    bins all_1_match = {0}; bins partial_match = {1};
  }
endgroup

covergroup cg_tkeep_tstrb_type_no_partial() with function sample (
    keep_strb_state_e keep_state, keep_strb_state_e strb_state
);
  option.per_instance = 1;

  cp_tkeep: coverpoint keep_state {
    bins all_1 = {KEEP_ALL_1}; ignore_bins ignore_all_0 = {KEEP_ALL_0};
  }
  cp_tstrb: coverpoint strb_state {
    bins all_1 = {KEEP_ALL_1}; ignore_bins ignore_all_0 = {KEEP_ALL_0};
  }
  cr_keep_strb: cross cp_tkeep, cp_tstrb;
endgroup

covergroup cg_sideband_type_mixed() with function sample (bit tlast, user_state_e user_state);
  option.per_instance = 1;
  option.weight = 0;  // [WV-AXIS-15] DUT does not use TUSER pin

  cp_tuser_state: coverpoint user_state {
    ignore_bins all_0 = {USER_ALL_0}; bins mixed = {USER_MIXED};
  }
  cp_tlast: coverpoint tlast;
  cr_tuser_tlast: cross cp_tlast, cp_tuser_state;
endgroup

covergroup cg_sideband_type_no_mixed() with function sample (bit tlast, user_state_e user_state);
  option.per_instance = 1;
  option.weight = 0;  // [WV-AXIS-16] DUT does not use TUSER pin

  cp_tuser_state: coverpoint user_state {ignore_bins all_0 = {USER_ALL_0};}
  cp_tlast: coverpoint tlast;
  // [WAIVER] There is no valid bin to hit
  // cr_tuser_tlast: cross cp_tlast, cp_tuser_state; 
endgroup


class axis_coverage extends uvm_subscriber #(axis_seq_item);

  `uvm_component_utils(axis_coverage)

  localparam int DataWidth = 1024;
  localparam int UserWidth = 1024;
  localparam int IdWidth = 32;
  localparam int DestWidth = 32;

  bit [IdWidth-1:0] prev_tid;
  bit [DestWidth-1:0] prev_tdest;
  bit is_first_tr = 1;

  bit m_can_partial;
  bit m_can_mixed;

  axis_agent_config m_cfg;

  logic [(DataWidth + 7) / 8 - 1 : 0] m_local_byte_mask;
  logic [DataWidth-1:0] m_local_data_mask;

  covergroup cg_handshake with function sample (int valid_wait_cycles, int ready_wait_cycles);
    option.per_instance = 1;
    cp_valid_wait: coverpoint valid_wait_cycles {
      bins zero_delay = {0};
      bins short_delay = {[1 : 5]};
      bins long_delay = {[6 : 20]};
      bins extreme_delay = {[21 : 100]};
      bins others = default;
    }

    // [WV-AXIS-07] DUT core backpressure is fixed at 69 cycles (extreme_backpressure)
    cp_ready_wait: coverpoint ready_wait_cycles {
      bins ready_first = {0};
      ignore_bins short_backpressure = {[1 : 5]};
      ignore_bins long_backpressure = {[6 : 20]};
      bins extreme_backpressure = {[21 : 100]};
      bins others = default;
    }
    cr_handshake_matrix: cross cp_valid_wait, cp_ready_wait;
  endgroup

  covergroup cg_packet_boundary with function sample (bit is_single_transfer, int inter_packet_gap);
    option.per_instance = 1;
    cp_transfer_type: coverpoint is_single_transfer {
      bins single_transfer = {1}; bins burst_transfer = {0};
    }
    // [WV-AXIS-08] Minimum 8-cycle IPG required for core execution and CSR restart
    cp_ipg: coverpoint inter_packet_gap {
      ignore_bins back_to_back = {0};
      ignore_bins short_gap = {[1 : 5]};
      bins long_gap = {[6 : 100]};
      bins others = default;
    }
    cr_packet_timing: cross cp_transfer_type, cp_ipg;
  endgroup

  covergroup cg_reset with function sample (bit reset_during_valid);
    option.per_instance = 1;
    cp_reset_valid: coverpoint reset_during_valid {
      bins clean_reset = {0}; bins active_transfer_reset = {1};
    }
  endgroup

  covergroup cg_null_transfer with function sample (bit tkeep_all_zero, bit tlast);
    option.per_instance = 1;
    // [WV-AXIS-09] Null beat (TKEEP=0) is unsupported by VIP and DUT
    cp_tkeep_all_zero: coverpoint tkeep_all_zero {
      bins normal = {0};
    }
    cp_tlast: coverpoint tlast {bins not_last = {0}; bins last = {1};}
    cr_null_tlast: cross cp_tkeep_all_zero, cp_tlast;
  endgroup

  cg_routing_matrix_type            cg_routing_matrix;
  cg_routing_change_type            cg_routing_change;

  cg_byte_qualifier_type_partial    cg_byte_qualifier_partial;
  cg_byte_qualifier_type_no_partial cg_byte_qualifier_no_partial;

  cg_tkeep_tstrb_type_partial       cg_tkeep_tstrb_partial;
  cg_tkeep_tstrb_type_no_partial    cg_tkeep_tstrb_no_partial;

  cg_sideband_type_mixed            cg_sideband_mixed;
  cg_sideband_type_no_mixed         cg_sideband_no_mixed;
  cg_data_pattern_type              cg_data_pattern;
  cg_backpressure_corner_type       cg_backpressure_corner;

  extern function new(string name = "axis_coverage", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern virtual function void write(axis_seq_item t);

endclass : axis_coverage


function axis_coverage::new(string name = "axis_coverage", uvm_component parent = null);
  super.new(name, parent);
  cg_handshake           = new();
  cg_packet_boundary     = new();
  cg_reset               = new();
  cg_null_transfer       = new();
  cg_data_pattern        = new();
  cg_backpressure_corner = new();
endfunction

function void axis_coverage::build_phase(uvm_phase phase);
  bit can_id_change;
  bit can_dest_change;

  super.build_phase(phase);

  m_cfg = axis_agent_config::get_config(this);

  m_local_byte_mask = '0;
  m_local_data_mask = '0;
  for (int b = 0; b < ((m_cfg.active_data_width + 7) / 8); b++) begin
    m_local_byte_mask[b] = 1'b1;
  end
  for (int b = 0; b < m_cfg.active_data_width; b++) begin
    m_local_data_mask[b] = 1'b1;
  end

  cg_routing_matrix = new(m_cfg.active_id_max, m_cfg.active_dest_max);

  can_id_change = (m_cfg.active_id_max > 0) ? 1'b1 : 1'b0;
  can_dest_change = (m_cfg.active_dest_max > 0) ? 1'b1 : 1'b0;
  cg_routing_change = new(can_id_change, can_dest_change);

  m_can_partial = (m_cfg.active_data_width > 8) ? 1'b1 : 1'b0;
  if (m_can_partial) begin
    cg_byte_qualifier_partial = new();
    cg_tkeep_tstrb_partial    = new();
  end else begin
    cg_byte_qualifier_no_partial = new();
    cg_tkeep_tstrb_no_partial    = new();
  end

  m_can_mixed = (m_cfg.active_user_width > 0) ? 1'b1 : 1'b0;
  if (m_can_mixed) begin
    cg_sideband_mixed = new();
  end else begin
    cg_sideband_no_mixed = new();
  end

endfunction

function void axis_coverage::write(axis_seq_item t);
  bit current_tlast;
  int pkt_size;
  bit id_changed;
  bit dest_changed;
  bit reset_during_valid;
  int ipg;
  logic [DataWidth-1:0] current_data;
  data_pattern_e data_pattern;
  bit tkeep_all_zero;
  bit stall_near_tlast;
  ready_stall_length_e stall_length;

  keep_strb_state_e keep_st, strb_st;
  user_state_e user_st;

  pkt_size = t.tdata_q.size();
  if (pkt_size == 0) return;

  reset_during_valid = (t.status == axis_seq_item::INCOMPLETE);
  cg_reset.sample(reset_during_valid);

  if (is_first_tr) begin
    id_changed   = 0;
    dest_changed = 0;
    is_first_tr  = 0;
  end else begin
    id_changed   = (t.tid != prev_tid);
    dest_changed = (t.tdest != prev_tdest);
  end

  cg_routing_change.sample(1'b1, id_changed, dest_changed);

  ipg = t.valid_delay_q[0];
  cg_packet_boundary.sample((pkt_size == 1), ipg);

  foreach (t.tdata_q[i]) begin
    current_tlast = (i == (pkt_size - 1));
    current_data  = t.tdata_q[i] & m_local_data_mask;

    if (current_data == '0) begin
      data_pattern = DATA_ALL_0;
      cg_data_pattern.sample(data_pattern, current_tlast);
    end else if (current_data == m_local_data_mask) begin
      data_pattern = DATA_ALL_1;
      cg_data_pattern.sample(data_pattern, current_tlast);
    end else if (is_toggle_pattern(current_data, m_cfg.active_data_width)) begin
      data_pattern = DATA_TOGGLE;
      cg_data_pattern.sample(data_pattern, current_tlast);
    end

    if ((t.tkeep_q[i] & m_local_byte_mask) == m_local_byte_mask) begin
      keep_st = KEEP_ALL_1;
    end else if ((t.tkeep_q[i] & m_local_byte_mask) == '0) begin
      keep_st = KEEP_ALL_0;
    end else begin
      keep_st = KEEP_PARTIAL;
    end

    if ((t.tstrb_q[i] & m_local_byte_mask) == m_local_byte_mask) begin
      strb_st = KEEP_ALL_1;
    end else if ((t.tstrb_q[i] & m_local_byte_mask) == '0) begin
      strb_st = KEEP_ALL_0;
    end else begin
      strb_st = KEEP_PARTIAL;
    end

    tkeep_all_zero = (keep_st == KEEP_ALL_0);
    cg_null_transfer.sample(tkeep_all_zero, current_tlast);

    if (t.ready_delay_q[i] > 0) begin
      stall_near_tlast = (i >= ((pkt_size > 1) ? pkt_size - 2 : 0));
      stall_length = (t.ready_delay_q[i] <= 5) ? READY_STALL_SHORT : READY_STALL_LONG;
      cg_backpressure_corner.sample(stall_near_tlast, stall_length);
    end

    if (t.tuser_q[i] == '0) user_st = USER_ALL_0;
    else user_st = USER_MIXED;

    cg_handshake.sample(t.valid_delay_q[i], t.ready_delay_q[i]);
    cg_routing_matrix.sample(t.tid, t.tdest);

    if (m_can_partial) begin
      cg_byte_qualifier_partial.sample(current_tlast, keep_st);
      cg_tkeep_tstrb_partial.sample(keep_st, strb_st);
    end else begin
      cg_byte_qualifier_no_partial.sample(current_tlast, keep_st);
      cg_tkeep_tstrb_no_partial.sample(keep_st, strb_st);
    end

    if (m_can_mixed) begin
      cg_sideband_mixed.sample(current_tlast, user_st);
    end else begin
      cg_sideband_no_mixed.sample(current_tlast, user_st);
    end
  end

  prev_tid   = t.tid;
  prev_tdest = t.tdest;
endfunction
