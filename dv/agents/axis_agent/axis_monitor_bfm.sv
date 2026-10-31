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
//   - Samples and reassembles AXI4-Stream packets from handshakes for SHA-256 analysis and coverage.
//------------------------------------------------------------------------------

interface axis_monitor_if (
    input logic aclk,
    input logic aresetn,
    axis_if vif
);

  import uvm_pkg::*;
  import axis_agent_pkg::*;

  localparam int DataWidth = 1024;
  localparam int UserWidth = 1024;
  localparam int IdWidth = 32;
  localparam int DestWidth = 32;

  axis_monitor proxy_q[$];

  axis_seq_item active_pkts[logic [IdWidth-1:0]];
  int v_delay_cnt = 0;
  int r_delay_cnt = 0;
  int ipg_cnt = 0;

  function automatic void register_proxy(axis_monitor p);
    proxy_q.push_back(p);
  endfunction

  task automatic flush();
    if (active_pkts.size() > 0) begin
      foreach (active_pkts[i]) begin
        axis_seq_item cloned_item;
        active_pkts[i].status = axis_seq_item::INCOMPLETE;
        $cast(cloned_item, active_pkts[i].clone());
        foreach (proxy_q[j]) begin
          proxy_q[j].notify_transaction(cloned_item);
        end
      end
    end
    active_pkts.delete();
    v_delay_cnt = 0;
    r_delay_cnt = 0;
    ipg_cnt = 0;
  endtask

  task automatic run();
    fork
      monitor_reset();
      monitor_bus();
    join
  endtask

  task automatic monitor_reset();
    forever begin
      wait (!aresetn);
      flush();
      wait (aresetn);
    end
  endtask

  task automatic monitor_bus();
    forever begin
      @(vif.mon_cb);
      if (aresetn) begin
        if (vif.mon_cb.tvalid == 1'b0) begin
          ipg_cnt++;
        end else begin
          if (vif.mon_cb.tready == 1'b0) begin
            r_delay_cnt++;
          end else begin
            logic [IdWidth-1:0] current_tid = vif.mon_cb.tid;
            axis_seq_item cloned_item;

            if (!active_pkts.exists(current_tid)) begin
              active_pkts[current_tid] = new("item");
              active_pkts[current_tid].tid = vif.mon_cb.tid;
              active_pkts[current_tid].tdest = vif.mon_cb.tdest;
              `uvm_info("AXIS_MON_BFM", $sformatf("PKT_START tid=0x%0h tdest=0x%0h ipg_cnt=%0d",
                                                  current_tid, vif.mon_cb.tdest, ipg_cnt), UVM_HIGH)
              v_delay_cnt = ipg_cnt;
              ipg_cnt = 0;
            end else begin
              v_delay_cnt = ipg_cnt;
              ipg_cnt = 0;
            end

            active_pkts[current_tid].tdata_q.push_back(vif.mon_cb.tdata);
            active_pkts[current_tid].tstrb_q.push_back(vif.mon_cb.tstrb);
            active_pkts[current_tid].tkeep_q.push_back(vif.mon_cb.tkeep);
            active_pkts[current_tid].tuser_q.push_back(vif.mon_cb.tuser);

            active_pkts[current_tid].valid_delay_q.push_back(v_delay_cnt);
            active_pkts[current_tid].ready_delay_q.push_back(r_delay_cnt);

            v_delay_cnt = 0;
            r_delay_cnt = 0;

            if (vif.mon_cb.tlast) begin
              active_pkts[current_tid].status = axis_seq_item::OK;
              $cast(cloned_item, active_pkts[current_tid].clone());
              foreach (proxy_q[j]) begin
                proxy_q[j].notify_transaction(cloned_item);
              end
              active_pkts.delete(current_tid);
            end
          end
        end
      end
    end
  endtask
endinterface : axis_monitor_if
