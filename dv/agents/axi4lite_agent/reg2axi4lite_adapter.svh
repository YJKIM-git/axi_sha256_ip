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
class reg2axi4lite_adapter extends uvm_reg_adapter;

  `uvm_object_utils(reg2axi4lite_adapter)

  axi4lite_agent_config m_cfg;

  function new(string name = "reg2axi4lite_adapter");
    super.new(name);
    supports_byte_enable = 1;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    axi4lite_seq_item trans_h = axi4lite_seq_item::type_id::create("trans_h");

    if (m_cfg == null) begin
      void'(uvm_config_db#(axi4lite_agent_config)::get(null, "*", "axi4lite_agent_config", m_cfg));
    end

    if (m_cfg != null && m_cfg.enable_random_delay) begin
      if (!trans_h.randomize()) begin
        `uvm_fatal("ADAPTER", "Randomization failed")
      end
    end else begin
      trans_h.aw_delay = 0;
      trans_h.w_delay  = 0;
      trans_h.b_delay  = 0;
      trans_h.ar_delay = 0;
      trans_h.r_delay  = 0;
    end

    trans_h.dir   = (rw.kind == UVM_READ) ? axi4lite_seq_item::READ : axi4lite_seq_item::WRITE;
    trans_h.addr  = rw.addr;
    trans_h.wdata = rw.data;
    trans_h.wstrb = rw.byte_en;
    trans_h.prot  = 3'b000;

    return trans_h;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    axi4lite_seq_item trans_h;

    if (!$cast(trans_h, bus_item)) begin
      `uvm_fatal("NOT_BUS_TYPE", "Provided bus_item is not of the correct type")
      return;
    end

    rw.kind = (trans_h.dir == axi4lite_seq_item::WRITE) ? UVM_WRITE : UVM_READ;
    rw.addr = trans_h.addr;
    rw.data = (trans_h.dir == axi4lite_seq_item::READ) ? trans_h.rdata : trans_h.wdata;

    if (trans_h.resp == 2'b00 || trans_h.resp == 2'b01) begin
      rw.status = UVM_IS_OK;
    end else begin
      rw.status = UVM_NOT_OK;
    end
  endfunction

endclass : reg2axi4lite_adapter
