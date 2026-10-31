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
//   - Instantiates the SHA-256 DUT, interfaces, BFMs, assertions, and hardware-side testbench top.
//------------------------------------------------------------------------------

module hdl_top;
  import uvm_pkg::*;
  logic clk_i;
  // AXIL VIP Setting
  assign AXI4LITE.rdata[63:32] = 32'd0;
  // core_agent Setting
  assign CORE.start_i          = DUT.u_core.start_i;
  assign CORE.ready_o          = DUT.u_core.ready_o;
  assign CORE.busy_o           = DUT.u_core.busy_o;
  assign CORE.done_o           = DUT.u_core.done_o;
  assign CORE.block_i          = DUT.u_core.block_i;
  assign CORE.state_in_i       = DUT.u_core.state_in_i;
  assign CORE.state_out_o      = DUT.u_core.state_out_o;

  assign CORE.pre_round_o      = DUT.u_core.u_controller.pre_round_o;
  assign CORE.round_idx_o      = DUT.u_core.u_controller.round_idx_o;
  assign CORE.load_block_o     = DUT.u_core.u_controller.load_block_o;
  assign CORE.round_en_o       = DUT.u_core.u_controller.round_en_o;
  assign CORE.init_o           = DUT.u_core.u_controller.init_o;
  assign CORE.update_o         = DUT.u_core.u_controller.update_o;
  assign CORE.first_block      = DUT.first_block;

  // =========================================================
  // 1. UTIL
  // =========================================================
  rst_bfm RST_bfm (
      .clk_i  (clk_i),
      .rst_n_o(rst_n_i)
  );
  intr_bfm INTR_bfm (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .irq_o  (irq_wire)
  );

  // =========================================================
  // 2. AGENT
  // =========================================================
  axi4lite_if AXI4LITE (
      clk_i,
      rst_n_i
  );
  axis_if AXIS (
      clk_i,
      rst_n_i
  );
  core_if CORE (
      clk_i,
      rst_n_i
  );
  axi4lite_monitor_bfm AXI4LITE_mon_bfm (
      .clk    (AXI4LITE.clk),
      .reset_n(AXI4LITE.reset_n),
      .awaddr (AXI4LITE.awaddr),
      .awprot (AXI4LITE.awprot),
      .awvalid(AXI4LITE.awvalid),
      .awready(AXI4LITE.awready),
      .wdata  (AXI4LITE.wdata),
      .wstrb  (AXI4LITE.wstrb),
      .wvalid (AXI4LITE.wvalid),
      .wready (AXI4LITE.wready),
      .bresp  (AXI4LITE.bresp),
      .bvalid (AXI4LITE.bvalid),
      .bready (AXI4LITE.bready),
      .araddr (AXI4LITE.araddr),
      .arprot (AXI4LITE.arprot),
      .arvalid(AXI4LITE.arvalid),
      .arready(AXI4LITE.arready),
      .rdata  (AXI4LITE.rdata),
      .rresp  (AXI4LITE.rresp),
      .rvalid (AXI4LITE.rvalid),
      .rready (AXI4LITE.rready)
  );
  axi4lite_driver_bfm AXI4LITE_drv_bfm (
      .clk    (AXI4LITE.clk),
      .reset_n(AXI4LITE.reset_n),
      .awaddr (AXI4LITE.awaddr),
      .awprot (AXI4LITE.awprot),
      .awvalid(AXI4LITE.awvalid),
      .awready(AXI4LITE.awready),
      .wdata  (AXI4LITE.wdata),
      .wstrb  (AXI4LITE.wstrb),
      .wvalid (AXI4LITE.wvalid),
      .wready (AXI4LITE.wready),
      .bresp  (AXI4LITE.bresp),
      .bvalid (AXI4LITE.bvalid),
      .bready (AXI4LITE.bready),
      .araddr (AXI4LITE.araddr),
      .arprot (AXI4LITE.arprot),
      .arvalid(AXI4LITE.arvalid),
      .arready(AXI4LITE.arready),
      .rdata  (AXI4LITE.rdata),
      .rresp  (AXI4LITE.rresp),
      .rvalid (AXI4LITE.rvalid),
      .rready (AXI4LITE.rready)
  );
  axis_monitor_if AXIS_mon_bfm (
      .aclk   (AXIS.aclk),
      .aresetn(AXIS.aresetn),
      .vif    (AXIS)
  );
  axis_m_driver_if AXIS_drv_bfm (
      .aclk   (AXIS.aclk),
      .aresetn(AXIS.aresetn),
      .vif    (AXIS)
  );
  core_monitor_bfm CORE_mon_bfm (
      .clk_i  (clk_i),
      .rst_n_i(DUT.core_rst_n),
      .vif    (CORE)
  );

  // =========================================================
  // 3. DUT
  // =========================================================
  sha256_axi_wrapper DUT (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),

      .s_axi_awaddr(AXI4LITE.awaddr[7:0]),
      .s_axi_awvalid(AXI4LITE.awvalid),
      .s_axi_awready(AXI4LITE.awready),
      .s_axi_awprot(AXI4LITE.awprot),  //added
      .s_axi_wdata(AXI4LITE.wdata[31:0]),
      .s_axi_wstrb(AXI4LITE.wstrb[3:0]),
      .s_axi_wvalid(AXI4LITE.wvalid),
      .s_axi_wready(AXI4LITE.wready),
      .s_axi_bresp(AXI4LITE.bresp),
      .s_axi_bvalid(AXI4LITE.bvalid),
      .s_axi_bready(AXI4LITE.bready),
      .s_axi_araddr(AXI4LITE.araddr[7:0]),
      .s_axi_arvalid(AXI4LITE.arvalid),
      .s_axi_arready(AXI4LITE.arready),
      .s_axi_arprot(AXI4LITE.arprot),  //added
      .s_axi_rdata(AXI4LITE.rdata[31:0]),
      .s_axi_rresp(AXI4LITE.rresp),
      .s_axi_rvalid(AXI4LITE.rvalid),
      .s_axi_rready(AXI4LITE.rready),

      .s_axis_tdata (AXIS.tdata[31:0]),
      .s_axis_tkeep (AXIS.tkeep[3:0]),
      .s_axis_tlast (AXIS.tlast),
      .s_axis_tvalid(AXIS.tvalid),
      .s_axis_tready(AXIS.tready),

      .irq_o(irq_wire)
  );

  // =========================================================
  // 4. Wrapper SVA
  // =========================================================
  bind DUT sha256_wrapper_sva bind_wrapper_sva (
      .clk_i             (clk_i),
      .rst_n_i           (rst_n_i),
      .state             (DUT.state),
      .ret_state         (DUT.ret_state),
      .ctrl_start_pulse  (DUT.ctrl_start_pulse),
      .ctrl_en           (DUT.ctrl_en),
      .ctrl_irq_en       (DUT.ctrl_irq_en),
      .slv_reg_rden      (DUT.slv_reg_rden),
      .araddr_reg        (DUT.araddr_reg),
      .ctrl_soft_reset   (DUT.ctrl_soft_reset),
      .status_busy       (DUT.status_busy),
      .status_done       (DUT.status_done),
      .irq_o             (DUT.irq_o),
      .msg_len           (DUT.msg_len),
      .byte_cnt          (DUT.byte_cnt),
      .first_block       (DUT.first_block),
      .block_b           (DUT.block_b),
      .transaction_active(DUT.transaction_active),
      .status_err_flag   (DUT.status_err_flag),
      .slv_reg_wren      (DUT.slv_reg_wren),
      .awaddr_reg        (DUT.awaddr_reg),
      .core_done         (DUT.core_done),
      .s_axis_tlast      (DUT.s_axis_tlast),
      .clear_done_pulse  (DUT.clear_done_pulse)
  );

  // =========================================================
  // 5. Core SVA
  // =========================================================
  bind DUT.u_core sha256_core_sva bind_core_sva (
      .clk_i       (clk_i),
      .rst_n_i     (rst_n_i),
      .start_i     (DUT.u_core.start_i),
      .ready_o     (DUT.u_core.ready_o),
      .busy_o      (DUT.u_core.busy_o),
      .done_o      (DUT.u_core.done_o),
      .block_i     (DUT.u_core.block_i),
      .state_in_i  (DUT.u_core.state_in_i),
      .init_o      (DUT.u_core.u_controller.init_o),
      .pre_round_o (DUT.u_core.u_controller.pre_round_o),
      .load_block_o(DUT.u_core.u_controller.load_block_o),
      .round_en_o  (DUT.u_core.u_controller.round_en_o),
      .update_o    (DUT.u_core.u_controller.update_o),
      .round_idx_o (DUT.u_core.u_controller.round_idx_o)
  );

  // =========================================================
  // 6. initial block
  // =========================================================
  initial begin : vif_registration
    import uvm_pkg::uvm_config_db;
    uvm_config_db#(virtual axi4lite_if)::set(null, "uvm_test_top", "AXI4LITE_vif", AXI4LITE);
    uvm_config_db#(virtual axi4lite_monitor_bfm)::set(null, "uvm_test_top", "AXI4LITE_mon_bfm",
                                                      AXI4LITE_mon_bfm);
    uvm_config_db#(virtual axi4lite_driver_bfm)::set(null, "uvm_test_top", "AXI4LITE_drv_bfm",
                                                     AXI4LITE_drv_bfm);
    uvm_config_db#(virtual axis_monitor_if)::set(null, "uvm_test_top", "AXIS_mon_bfm",
                                                 AXIS_mon_bfm);
    uvm_config_db#(virtual axis_m_driver_if)::set(null, "uvm_test_top", "AXIS_drv_bfm",
                                                  AXIS_drv_bfm);
    uvm_config_db#(virtual intr_bfm)::set(null, "uvm_test_top", "INTR_bfm", INTR_bfm);
    uvm_config_db#(virtual rst_bfm)::set(null, "uvm_test_top", "RST_bfm", RST_bfm);
    uvm_config_db#(virtual core_monitor_bfm)::set(null, "uvm_test_top", "CORE_mon_bfm",
                                                  CORE_mon_bfm);
  end

  initial begin : clk_gen
    clk_i = 0;
    forever #5ns clk_i = ~clk_i;
  end

  /*
  initial begin // VCD Dump
    $dumpfile("wave.vcd");
    $dumpvars(0, hdl_top);
  end
  */
endmodule : hdl_top
