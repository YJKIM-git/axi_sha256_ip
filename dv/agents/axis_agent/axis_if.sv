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
//   - Defines the 1024-bit AXI4-Stream interface, clocking blocks, and protocol assertions used by the SHA-256 testbench.
//------------------------------------------------------------------------------

interface axis_if (
    input logic aclk,
    input logic aresetn
);

  localparam int DataWidth = 1024;
  localparam int UserWidth = 1024;
  localparam int IdWidth   = 32;
  localparam int DestWidth = 32;
  localparam int StrbWidth = (DataWidth + 7) / 8;
  parameter int MAXWAITS = 2048;

  logic                  tvalid;
  logic                  tready;
  logic [DataWidth-1:0] tdata;
  logic [StrbWidth-1:0] tstrb;
  logic [StrbWidth-1:0] tkeep;
  logic                  tlast;
  logic [  IdWidth-1:0] tid;
  logic [DestWidth-1:0] tdest;
  logic [UserWidth-1:0] tuser;

  clocking dr_m_cb @(posedge aclk);
    default input #1step output #1ns;
    output tvalid;
    output tdata;
    output tstrb;
    output tkeep;
    output tlast;
    output tid;
    output tdest;
    output tuser;
    input tready;
  endclocking
  modport DR_M(clocking dr_m_cb, input aclk, aresetn);

  clocking dr_s_cb @(posedge aclk);
    default input #1step output #1ns;
    input tvalid;
    input tdata;
    input tstrb;
    input tkeep;
    input tlast;
    input tid;
    input tdest;
    input tuser;
    output tready;
  endclocking
  modport DR_S(clocking dr_s_cb, input aclk, aresetn);

  clocking mon_cb @(posedge aclk);
    default input #1step;
    input tvalid;
    input tdata;
    input tstrb;
    input tkeep;
    input tlast;
    input tid;
    input tdest;
    input tuser;
    input tready;
  endclocking
  modport MON(clocking mon_cb, input aclk, aresetn);


  property p_err_tvalid_reset;
    @(posedge aclk) $rose(aresetn) |-> !tvalid;
  endproperty
  assert property (p_err_tvalid_reset);

  `define ASSERT_STABLE(sig) \
    assert property (@(posedge aclk) disable iff (!aresetn) $past(tvalid) && !$past(tready) |-> $stable(sig))

  `ASSERT_STABLE(tid);
  `ASSERT_STABLE(tdest);
  `ASSERT_STABLE(tdata);
  `ASSERT_STABLE(tstrb);
  `ASSERT_STABLE(tlast);
  `ASSERT_STABLE(tkeep);
  `ASSERT_STABLE(tuser);
  `ASSERT_STABLE(tvalid);

  `define ASSERT_X_WHEN_VALID(sig) \
    assert property (@(posedge aclk) disable iff (!aresetn) tvalid |-> !$isunknown(sig))

  `ASSERT_X_WHEN_VALID(tid);
  `ASSERT_X_WHEN_VALID(tdest);
  `ASSERT_X_WHEN_VALID(tdata);
  `ASSERT_X_WHEN_VALID(tstrb);
  `ASSERT_X_WHEN_VALID(tlast);
  `ASSERT_X_WHEN_VALID(tkeep);

  `define ASSERT_X_NOT_IN_RESET(sig) \
    assert property (@(posedge aclk) disable iff (!aresetn) !$isunknown(sig))

  `ASSERT_X_NOT_IN_RESET(tvalid);
  `ASSERT_X_NOT_IN_RESET(tready);
  `ASSERT_X_NOT_IN_RESET(tuser);

  property p_err_tkeep_tstrb;
    @(posedge aclk) disable iff (!aresetn) tvalid |-> ((~tkeep & tstrb) == 0);
  endproperty
  assert property (p_err_tkeep_tstrb);

  property p_rec_tready_max_wait;
    @(posedge aclk) disable iff (!aresetn) tvalid && !tready |-> ##[1:MAXWAITS] tready;
  endproperty
  assert property (p_rec_tready_max_wait);

endinterface : axis_if

  // unsupported SVA (https://support.arm.com/documentation/dui0534/b/Protocol-Assertions-Descriptions/AXI4-Stream-protocol-assertion-descriptions)
  // 1. [COVERED] AXI4STREAM_ERRM_STREAM_ALL_DONE_EOS [covered on moniter check_phase]
  // 2. [NOT SUPPORTED] AXI4STREAM_ERRM_TIEOFF(TDATA, TKEEP, TSTRB, TID, TDEST, TUSER)
  //    Not supported in this vip. this case is when DATAWITH is 0.
  //    and this vip does not support DATAWITH is 0 case.

