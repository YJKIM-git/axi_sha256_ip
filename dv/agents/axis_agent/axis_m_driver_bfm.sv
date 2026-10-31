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
//   - Implements AXI4-Stream master beat queuing, arbitration, driving, and timeout handling for SHA-256 verification.
//------------------------------------------------------------------------------

interface axis_m_driver_if (
    input logic aclk,
    input logic aresetn,
    axis_if vif
);

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import axis_agent_pkg::*;
  localparam int DataWidth = 1024;
  localparam int UserWidth = 1024;
  localparam int IdWidth = 32;
  localparam int DestWidth = 32;
  localparam int StrbWidth = (DataWidth + 7) / 8;

  typedef struct {
    logic [DataWidth-1:0] tdata;
    logic [StrbWidth-1:0] tstrb;
    logic [StrbWidth-1:0] tkeep;
    logic [UserWidth-1:0] tuser;
    logic [DestWidth-1:0] tdest;
    logic                 tlast;
    int                   valid_delay;
  } axis_beat_t;

  typedef axis_beat_t beat_queue_t[$];
  beat_queue_t active_pkt_q[logic [IdWidth-1:0]];

  logic [IdWidth-1:0] tid_rr_q[$];
  bit shadow_tvalid = 1'b0;

  task automatic push_transaction(axis_seq_item item);
    logic [IdWidth-1:0] tid_val;
    axis_beat_t beat;
    int pkt_len;

    pkt_len = item.tdata_q.size();
    if (pkt_len == 0) return;

    tid_val = item.tid;

    if (!active_pkt_q.exists(tid_val)) begin
      tid_rr_q.push_back(tid_val);
    end

    for (int i = 0; i < pkt_len; i++) begin
      beat.tdata       = item.tdata_q[i];
      beat.tstrb       = item.tstrb_q[i];
      beat.tkeep       = item.tkeep_q[i];
      beat.tuser       = item.tuser_q[i];
      beat.tdest       = item.tdest;
      beat.valid_delay = item.valid_delay_q[i];
      beat.tlast       = (i == pkt_len - 1) && (!item.drop_tlast);

      active_pkt_q[tid_val].push_back(beat);
    end
  endtask

  function automatic int get_total_beats();
    int total = 0;
    foreach (tid_rr_q[i]) begin
      if (active_pkt_q.exists(tid_rr_q[i])) begin
        total += active_pkt_q[tid_rr_q[i]].size();
      end
    end
    return total;
  endfunction

  task automatic wait_pkt_done(logic [IdWidth-1:0] tid_val, int timeout_cycles,
                               output bit completed);
    int wait_cnt;
    int current_beats;

    completed = 1'b0;
    wait_cnt = 0;
    current_beats = get_total_beats();

    while (active_pkt_q.exists(
        tid_val
    )) begin
      @(posedge aclk);
      if (get_total_beats() < current_beats) begin
        wait_cnt = 0;
        current_beats = get_total_beats();
      end else begin
        wait_cnt++;
      end

      if (wait_cnt > timeout_cycles) begin
        `uvm_error("AXIS_M_DRV_BFM",
                   $sformatf("wait_pkt_done timeout for tid=0x%0h (Stalled for %0d cycles)",
                             tid_val, timeout_cycles))
        active_pkt_q.delete(tid_val);
        foreach (tid_rr_q[i]) begin
          if (tid_rr_q[i] == tid_val) begin
            tid_rr_q.delete(i);
            break;
          end
        end
        return;
      end
    end
    completed = 1'b1;
  endtask

  bit is_driving;
  task automatic flush();
    active_pkt_q.delete();
    tid_rr_q.delete();
    shadow_tvalid = 1'b0;
    is_driving = 1'b0;
  endtask

  task automatic wait_for_reset();
    wait (!aresetn);
    flush();
    wait (aresetn);
  endtask

  task automatic drive_bus(axis_agent_config cfg);
    logic [IdWidth-1:0] current_tid;
    axis_beat_t current_beat;
    int wait_cycles;
    int rand_idx;

    is_driving  = 1'b0;
    wait_cycles = 0;

    forever
      @(vif.dr_m_cb) begin
        if (!aresetn) begin
          vif.dr_m_cb.tvalid <= 1'b0;
          vif.dr_m_cb.tdata  <= '0;
          vif.dr_m_cb.tstrb  <= '0;
          vif.dr_m_cb.tkeep  <= '0;
          vif.dr_m_cb.tuser  <= '0;
          vif.dr_m_cb.tdest  <= '0;
          vif.dr_m_cb.tid    <= '0;
          vif.dr_m_cb.tlast  <= 1'b0;
          shadow_tvalid = 1'b0;
          is_driving = 1'b0;
          wait_cycles = 0;
          active_pkt_q.delete();
          tid_rr_q.delete();
        end else begin
          if (is_driving && shadow_tvalid) begin
            if (vif.dr_m_cb.tready === 1'b1) begin
              if (active_pkt_q.exists(current_tid) && active_pkt_q[current_tid].size() > 0) begin
                void'(active_pkt_q[current_tid].pop_front());
                if (active_pkt_q[current_tid].size() == 0) begin
                  active_pkt_q.delete(current_tid);
                  foreach (tid_rr_q[i]) begin
                    if (tid_rr_q[i] == current_tid) begin
                      tid_rr_q.delete(i);
                      break;
                    end
                  end
                end
              end
              is_driving = 1'b0;
              vif.dr_m_cb.tvalid <= 1'b0;
              shadow_tvalid = 1'b0;
              wait_cycles   = 0;
            end else if (vif.dr_m_cb.tready === 1'bx) begin
              `uvm_error("AXIS_M_DRV_BFM", "tready is Unknown (X)")
              active_pkt_q.delete(current_tid);
              foreach (tid_rr_q[i]) begin
                if (tid_rr_q[i] == current_tid) begin
                  tid_rr_q.delete(i);
                  break;
                end
              end
              is_driving = 1'b0;
              vif.dr_m_cb.tvalid <= 1'b0;
              shadow_tvalid = 1'b0;
              wait_cycles   = 0;
            end else begin
              wait_cycles++;
              if (wait_cycles > cfg.timeout_cycles) begin
                `uvm_error("AXIS_M_DRV_BFM", "tready timeout occurred")
                active_pkt_q.delete(current_tid);
                foreach (tid_rr_q[i]) begin
                  if (tid_rr_q[i] == current_tid) begin
                    tid_rr_q.delete(i);
                    break;
                  end
                end
                is_driving = 1'b0;
                vif.dr_m_cb.tvalid <= 1'b0;
                shadow_tvalid = 1'b0;
                wait_cycles   = 0;
              end
            end
          end

          if (!is_driving && tid_rr_q.size() > 0) begin
            if (cfg.arb_mode == ARB_RANDOM) begin
              rand_idx = $urandom_range(0, tid_rr_q.size() - 1);
              current_tid = tid_rr_q[rand_idx];
              tid_rr_q.delete(rand_idx);
              tid_rr_q.push_back(current_tid);
            end else begin
              current_tid = tid_rr_q.pop_front();
              tid_rr_q.push_back(current_tid);
            end

            if (active_pkt_q.exists(current_tid) && active_pkt_q[current_tid].size() > 0) begin
              current_beat = active_pkt_q[current_tid][0];

              if (current_beat.valid_delay > 0) begin
                active_pkt_q[current_tid][0].valid_delay--;
                vif.dr_m_cb.tvalid <= 1'b0;
                shadow_tvalid <= 1'b0;
              end else begin
                vif.dr_m_cb.tvalid <= 1'b1;
                shadow_tvalid <= 1'b1;
                vif.dr_m_cb.tdata  <= current_beat.tdata;
                vif.dr_m_cb.tstrb  <= current_beat.tstrb;
                vif.dr_m_cb.tkeep  <= current_beat.tkeep;
                vif.dr_m_cb.tuser  <= current_beat.tuser;
                vif.dr_m_cb.tdest  <= current_beat.tdest;
                vif.dr_m_cb.tid    <= current_tid;
                vif.dr_m_cb.tlast  <= current_beat.tlast;
                is_driving  = 1'b1;
                wait_cycles = 0;
              end
            end
          end else if (!is_driving) begin
            vif.dr_m_cb.tvalid <= 1'b0;
            shadow_tvalid <= 1'b0;
            vif.dr_m_cb.tlast <= 1'b0;
          end
        end
      end
  endtask
endinterface : axis_m_driver_if
