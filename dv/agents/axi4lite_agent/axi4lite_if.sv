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
interface axi4lite_if (
    input logic clk,
    input logic reset_n
);
  localparam int ADDR_WIDTH = 64;
  localparam int DATA_WIDTH = 64;
  localparam int StrbWidth = DATA_WIDTH / 8;

  int                    cfg_data_width = 32;
  int                    cfg_addr_width = 32;  // 추가된 런타임 주소 폭 제어 변수
  bit                    disable_alignment_sva = 0;
  bit                    disable_timeout_sva = 0;

  logic [ADDR_WIDTH-1:0] awaddr;
  logic [           2:0] awprot;
  logic                  awvalid;
  logic                  awready;

  logic [DATA_WIDTH-1:0] wdata;
  logic [ StrbWidth-1:0] wstrb;
  logic                  wvalid;
  logic                  wready;

  logic [           1:0] bresp;
  logic                  bvalid;
  logic                  bready;

  logic [ADDR_WIDTH-1:0] araddr;
  logic [           2:0] arprot;
  logic                  arvalid;
  logic                  arready;

  logic [DATA_WIDTH-1:0] rdata;
  logic [           1:0] rresp;
  logic                  rvalid;
  logic                  rready;

  logic [31:0] outstanding_aw_cnt, aw_done_cnt;
  logic [31:0] outstanding_w_cnt, w_done_cnt;
  logic [31:0] outstanding_ar_cnt, ar_done_cnt;
  logic [31:0] b_done_cnt, r_done_cnt;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      outstanding_aw_cnt <= 0;
      aw_done_cnt <= 0;
      outstanding_w_cnt <= 0;
      w_done_cnt <= 0;
      outstanding_ar_cnt <= 0;
      ar_done_cnt <= 0;
      b_done_cnt <= 0;
      r_done_cnt <= 0;
    end else begin
      if (awvalid && awready) begin
        outstanding_aw_cnt <= outstanding_aw_cnt + 1;
        aw_done_cnt <= aw_done_cnt + 1;
      end
      if (wvalid && wready) begin
        outstanding_w_cnt <= outstanding_w_cnt + 1;
        w_done_cnt <= w_done_cnt + 1;
      end
      if (arvalid && arready) begin
        outstanding_ar_cnt <= outstanding_ar_cnt + 1;
        ar_done_cnt <= ar_done_cnt + 1;
      end

      if (bvalid && bready) begin
        outstanding_aw_cnt <= outstanding_aw_cnt - 1;
        outstanding_w_cnt <= outstanding_w_cnt - 1;
        b_done_cnt <= b_done_cnt + 1;
      end
      if (rvalid && rready) begin
        outstanding_ar_cnt <= outstanding_ar_cnt - 1;
        r_done_cnt <= r_done_cnt + 1;
      end
    end
  end

  property p_min_reset_duration;
    @(posedge clk) $rose(
        reset_n
    ) |-> $past(
        !reset_n, 16
    ) == 1;
  endproperty
  a_min_reset_duration :
  assert property (p_min_reset_duration);

  property p_valid_low_during_reset;
    @(posedge clk) !reset_n |-> (!awvalid && !wvalid && !bvalid && !arvalid && !rvalid);
  endproperty
  a_valid_low_during_reset :
  assert property (p_valid_low_during_reset);

  property p_valid_low_after_reset;
    @(posedge clk) $rose(
        reset_n
    ) |-> (!awvalid && !wvalid && !bvalid && !arvalid && !rvalid);
  endproperty
  a_valid_low_after_reset :
  assert property (p_valid_low_after_reset);

  property p_valid_not_unknown;
    @(posedge clk) disable iff (!reset_n) !$isunknown(
        {awvalid, wvalid, bvalid, arvalid, rvalid}
    );
  endproperty
  a_valid_not_unknown :
  assert property (p_valid_not_unknown);

  property p_ready_not_unknown;
    @(posedge clk) disable iff (!reset_n) !$isunknown(
        {awready, wready, bready, arready, rready}
    );
  endproperty
  a_ready_not_unknown :
  assert property (p_ready_not_unknown);

  property p_addr_not_unknown;
    @(posedge clk) disable iff (!reset_n) (awvalid |-> !$isunknown(
        awaddr
    )) and(arvalid |-> !$isunknown(
        araddr
    ));
  endproperty
  a_addr_not_unknown :
  assert property (p_addr_not_unknown);

  property p_aw_stability;
    @(posedge clk) disable iff (!reset_n) (awvalid && !awready) |=> awvalid && $stable(
        awaddr
    ) && $stable(
        awprot
    );
  endproperty
  a_aw_stability :
  assert property (p_aw_stability);

  property p_w_stability;
    @(posedge clk) disable iff (!reset_n) (wvalid && !wready) |=> wvalid && $stable(
        wdata
    ) && $stable(
        wstrb
    );
  endproperty
  a_w_stability :
  assert property (p_w_stability);

  property p_ar_stability;
    @(posedge clk) disable iff (!reset_n) (arvalid && !arready) |=> arvalid && $stable(
        araddr
    ) && $stable(
        arprot
    );
  endproperty
  a_ar_stability :
  assert property (p_ar_stability);

  property p_r_stability;
    @(posedge clk) disable iff (!reset_n) (rvalid && !rready) |=> rvalid && $stable(
        rdata
    ) && $stable(
        rresp
    );
  endproperty
  a_r_stability :
  assert property (p_r_stability);

  property p_b_stability;
    @(posedge clk) disable iff (!reset_n) (bvalid && !bready) |=> bvalid && $stable(
        bresp
    );
  endproperty
  a_b_stability :
  assert property (p_b_stability);

  property p_addr_alignment_64;
    @(posedge clk) disable iff (!reset_n || cfg_data_width != 64 || disable_alignment_sva)
    (awvalid |-> (awaddr[2:0] == 3'b000)) and
    (arvalid |-> (araddr[2:0] == 3'b000));
  endproperty
  a_addr_alignment_64 :
  assert property (p_addr_alignment_64);

  property p_addr_alignment_32;
    @(posedge clk) disable iff (!reset_n || cfg_data_width != 32 || disable_alignment_sva)
    (awvalid |-> (awaddr[1:0] == 2'b00)) and
    (arvalid |-> (araddr[1:0] == 2'b00));
  endproperty
  a_addr_alignment_32 :
  assert property (p_addr_alignment_32);

  property p_prot_no_unknown;
    @(posedge clk) disable iff (!reset_n) (awvalid |-> !$isunknown(
        awprot
    )) and(arvalid |-> !$isunknown(
        arprot
    ));
  endproperty
  a_prot_no_unknown :
  assert property (p_prot_no_unknown);

  property p_wstrb_no_unknown;
    @(posedge clk) disable iff (!reset_n) wvalid |-> !$isunknown(
        wstrb
    );
  endproperty
  a_wstrb_no_unknown :
  assert property (p_wstrb_no_unknown);

  generate
    for (genvar i = 0; i < StrbWidth; i++) begin : gen_wdata_check
      property p_wdata_lane_not_unknown;
        @(posedge clk) disable iff (!reset_n) wvalid |-> (!wstrb[i] || !$isunknown(
            wdata[(i*8)+7 : i*8]
        ));
      endproperty
      a_wdata_lane_not_unknown :
      assert property (p_wdata_lane_not_unknown);
    end
  endgenerate

  property p_rdata_not_unknown;
    @(posedge clk) disable iff (!reset_n) rvalid |-> (cfg_data_width == 32) ? !$isunknown(
        rdata[31:0]
    ) : !$isunknown(
        rdata
    );
  endproperty
  a_rdata_not_unknown :
  assert property (p_rdata_not_unknown);

  property p_resp_no_exokay;
    @(posedge clk) disable iff (!reset_n)
    (bvalid |-> (bresp != 2'b01)) and
    (rvalid |-> (rresp != 2'b01));
  endproperty
  a_resp_no_exokay :
  assert property (p_resp_no_exokay);

  property p_aw_timeout;
    @(posedge clk) disable iff (!reset_n || disable_timeout_sva) awvalid |-> ##[0:100] awready;
  endproperty
  a_aw_timeout :
  assert property (p_aw_timeout);

  property p_w_timeout;
    @(posedge clk) disable iff (!reset_n || disable_timeout_sva) wvalid |-> ##[0:100] wready;
  endproperty
  a_w_timeout :
  assert property (p_w_timeout);

  property p_b_timeout;
    @(posedge clk) disable iff (!reset_n || disable_timeout_sva) bvalid |-> ##[0:100] bready;
  endproperty
  a_b_timeout :
  assert property (p_b_timeout);

  property p_ar_timeout;
    @(posedge clk) disable iff (!reset_n || disable_timeout_sva) arvalid |-> ##[0:100] arready;
  endproperty
  a_ar_timeout :
  assert property (p_ar_timeout);

  property p_r_timeout;
    @(posedge clk) disable iff (!reset_n || disable_timeout_sva) rvalid |-> ##[0:100] rready;
  endproperty
  a_r_timeout :
  assert property (p_r_timeout);

  property p_bvalid_dependency;
    @(posedge clk) disable iff (!reset_n)
    bvalid |-> (outstanding_aw_cnt > 0) && (outstanding_w_cnt > 0);
  endproperty
  a_bvalid_dependency :
  assert property (p_bvalid_dependency);

  property p_rvalid_dependency;
    @(posedge clk) disable iff (!reset_n) rvalid |-> (outstanding_ar_cnt > 0);
  endproperty
  a_rvalid_dependency :
  assert property (p_rvalid_dependency);

  property p_write_one_to_one;
    @(posedge clk) disable iff (!reset_n) (b_done_cnt <= aw_done_cnt) && (b_done_cnt <= w_done_cnt);
  endproperty
  a_write_one_to_one :
  assert property (p_write_one_to_one);

  property p_read_one_to_one;
    @(posedge clk) disable iff (!reset_n) (r_done_cnt <= ar_done_cnt);
  endproperty
  a_read_one_to_one :
  assert property (p_read_one_to_one);

  property p_addr_bounds;
    @(posedge clk) disable iff (!reset_n || cfg_addr_width == 64)
    (awvalid |-> (awaddr >> cfg_addr_width) == 0) and
    (arvalid |-> (araddr >> cfg_addr_width) == 0);
  endproperty
  a_addr_bounds :
  assert property (p_addr_bounds);

endinterface : axi4lite_if
