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
//   - Preserves the unused AXI4-Stream slave driver BFM for future slave-mode verification environments.
//------------------------------------------------------------------------------

interface axis_s_driver_if (
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

  int ready_delay_q[$];
  int current_delay = 0;
  bit is_waiting = 0;

  task automatic push_transaction(axis_seq_item item);
    int pkt_len;

    pkt_len = item.ready_delay_q.size();
    if (pkt_len == 0) return;

    for (int i = 0; i < pkt_len; i++) begin
      ready_delay_q.push_back(item.ready_delay_q[i]);
    end
  endtask

  task automatic wait_pkt_done();
    wait ((ready_delay_q.size() == 0) && (is_waiting == 0));
  endtask

  task automatic flush();
    ready_delay_q.delete();
    is_waiting = 0;
    current_delay = 0;
  endtask

  task automatic wait_for_reset();
    wait (!aresetn);
    flush();
    wait (aresetn);
  endtask

  task automatic drive_bus(axis_agent_config cfg);
    int wait_valid_cycles;

    wait_valid_cycles = 0;

    forever
      @(vif.dr_s_cb) begin
        if (!aresetn) begin
          vif.dr_s_cb.tready <= 1'b0;
          is_waiting = 0;
          current_delay = 0;
          wait_valid_cycles = 0;
          ready_delay_q.delete();
        end else begin
          if (!is_waiting && ready_delay_q.size() > 0) begin
            current_delay = ready_delay_q.pop_front();
            is_waiting = 1;
            wait_valid_cycles = 0;
          end

          if (is_waiting) begin
            if (current_delay > 0) begin
              vif.dr_s_cb.tready <= 1'b0;
              current_delay--;
            end else begin
              vif.dr_s_cb.tready <= 1'b1;
              if (vif.dr_s_cb.tvalid === 1'b1) begin
                is_waiting = 0;
                wait_valid_cycles = 0;
              end else begin
                wait_valid_cycles++;
                if (wait_valid_cycles > cfg.timeout_cycles) begin
                  is_waiting = 0;
                  wait_valid_cycles = 0;
                end
              end
            end
          end else begin
            vif.dr_s_cb.tready <= 1'b1;
          end
        end
      end
  endtask
endinterface : axis_s_driver_if
