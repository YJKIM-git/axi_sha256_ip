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
//   - Samples SHA-256 core activity and reset behavior at the signal level.
//------------------------------------------------------------------------------

interface core_monitor_bfm (
    input logic clk_i,
    input logic rst_n_i,
    core_if vif
);

  import uvm_pkg::*;
  import core_agent_pkg::*;

  core_monitor  proxy;
  core_seq_item active_q[$];

  function automatic void register_proxy(core_monitor p);
    proxy = p;
  endfunction

  function automatic void send_to_proxy(core_seq_item item);
    core_seq_item cloned_item;
    if (proxy != null) begin
      $cast(cloned_item, item.clone());
      proxy.notify_transaction(cloned_item);
    end
  endfunction

  task automatic run();
    fork
      monitor_write();
      monitor_read();
    join
  endtask

  task automatic monitor_write();
    core_seq_item item;
    forever begin
      @(vif.mon_cb);
      if (rst_n_i && vif.mon_cb.start_i && vif.mon_cb.ready_o) begin
        item = core_seq_item::type_id::create("item");
        item.block_i    = vif.mon_cb.block_i;
        item.state_in_i = vif.mon_cb.state_in_i;
        item.first_block = vif.mon_cb.first_block;
        active_q.push_back(item);
      end
    end
  endtask

  task automatic monitor_read();
    core_seq_item       item;
    int                 cycle_cnt;
    logic         [5:0] current_round;

    forever begin
      wait (active_q.size() > 0);
      item = active_q.pop_front();
      cycle_cnt = 0;
      current_round = vif.mon_cb.round_idx_o;

      fork
        // Thread A: normal completion (Done)
        begin : wait_done
          do begin
            @(vif.mon_cb);
            cycle_cnt++;
            current_round = vif.mon_cb.round_idx_o;
          end while (!vif.mon_cb.done_o);

          item.is_aborted  = 1'b0;
          item.latency     = cycle_cnt;
          item.state_out_o = vif.mon_cb.state_out_o;
          send_to_proxy(item);
        end

        // Thread B: Exception (Reset)
        begin : wait_async_reset
          wait (rst_n_i == 1'b0);

          item.is_aborted    = 1'b1;
          item.aborted_cycle = cycle_cnt;
          item.aborted_round = current_round;
          send_to_proxy(item);
        end
      join_any

      disable fork;

      if (!rst_n_i) begin
        wait (rst_n_i == 1'b1);
        active_q.delete();
      end
    end
  endtask

endinterface : core_monitor_bfm
