
# AXI4-Stream Protocol Assertion Descriptions

> **출처:** [Arm Support Documentation](https://support.arm.com/documentation/dui0534/b/Protocol-Assertions-Descriptions/AXI4-Stream-protocol-assertion-descriptions)

This section describes the protocol assertions and indicates the area of the **AMBA 4 AXI4-Stream Protocol v1.0** specification to which they apply.

### Table 4.10. Streaming Channel Assertion Rules

| Assertion | Description | Specification Reference |
| --- | --- | --- |
| `AXI4STREAM_ERRM_TVALID_RESET` | `TVALID` is LOW for the first cycle after `ARESETn` goes HIGH | Reset on Page 2-11 |
| `AXI4STREAM_ERRM_TID_STABLE` | `TID` remains stable when `TVALID` is asserted, and `TREADY` is LOW | Handshake process on Page 2-3 |
| `AXI4STREAM_ERRM_TDEST_STABLE` | `TDEST` remains stable when `TVALID` is asserted, and `TREADY` is LOW | Handshake process on Page 2-3 |
| `AXI4STREAM_ERRM_TDATA_STABLE` | `TDATA` remains stable when `TVALID` is asserted, and `TREADY` is LOW | Handshake process on Page 2-3 |
| `AXI4STREAM_ERRM_TSTRB_STABLE` | `TSTRB` remains stable when `TVALID` is asserted, and `TREADY` is LOW | Handshake process on Page 2-3 |
| `AXI4STREAM_ERRM_TLAST_STABLE` | `TLAST` remains stable when `TVALID` is asserted, and `TREADY` is LOW | Handshake process on Page 2-3 |
| `AXI4STREAM_ERRM_TKEEP_STABLE` | `TKEEP` remains stable when `TVALID` is asserted, and `TREADY` is LOW | Handshake process on Page 2-3 |
| `AXI4STREAM_ERRM_TVALID_STABLE` | When `TVALID` is asserted, then it must remain asserted until `TREADY` is HIGH | Handshake process on Page 2-3 |
| `AXI4STREAM_RECS_TREADY_MAX_WAIT` | Recommended that `TREADY` is asserted within `MAXWAITS` cycles of `TVALID` being asserted | - |
| `AXI4STREAM_ERRM_TID_X` | A value of X on `TID` is not permitted when `TVALID` is HIGH | - |
| `AXI4STREAM_ERRM_TDEST_X` | A value of X on `TDEST` is not permitted when `TVALID` is HIGH | - |
| `AXI4STREAM_ERRM_TDATA_X` | A value of X on `TDATA` is not permitted when `TVALID` is HIGH | - |
| `AXI4STREAM_ERRM_TSTRB_X` | A value of X on `TSTRB` is not permitted when `TVALID` is HIGH | - |
| `AXI4STREAM_ERRM_TLAST_X` | A value of X on `TLAST` is not permitted when `TVALID` is HIGH | - |
| `AXI4STREAM_ERRM_TKEEP_X` | A value of X on `TKEEP` is not permitted when `TVALID` is HIGH | - |
| `AXI4STREAM_ERRM_TVALID_X` | A value of X on `TVALID` is not permitted when not in reset | - |
| `AXI4STREAM_ERRS_TREADY_X` | A value of X on `TREADY` is not permitted when not in reset | - |
| `AXI4STREAM_ERRM_TUSER_X` | A value of X on `TUSER` is not permitted when not in reset | - |
| `AXI4STREAM_ERRM_TUSER_STABLE` | `TUSER` payload signals must remain constant while `TVALID` is asserted, and `TREADY` is de-asserted | Handshake process on Page 2-3 |
| `AXI4STREAM_ERRM_STREAM_ALL_DONE_EOS` | At the end of simulation, all streams have had their corresponding `TLAST` transfer | - |
| `AXI4STREAM_ERRM_TKEEP_TSTRB` | If `TKEEP` is de-asserted, then `TSTRB` must also be de-asserted | Table 2-2 on Page 2-9 |
| `AXI4STREAM_ERRM_TDATA_TIEOFF` | `TDATA` must be stable while `DATA_WIDTH_BYTES` has been set to zero | - |
| `AXI4STREAM_ERRM_TKEEP_TIEOFF` | `TKEEP` must be stable while `DATA_WIDTH_BYTES` has been set to zero | - |
| `AXI4STREAM_ERRM_TSTRB_TIEOFF` | `TSTRB` must be stable while `DATA_WIDTH_BYTES` has been set to zero | - |
| `AXI4STREAM_ERRM_TID_TIEOFF` | `TID` must be stable while `ID_WIDTH` has been set to zero | - |
| `AXI4STREAM_ERRM_TDEST_TIEOFF` | `TDEST` must be stable while `DEST_WIDTH` has been set to zero | - |
| `AXI4STREAM_ERRM_TUSER_TIEOFF` | `TUSER` must be stable while `USER_WIDTH` has been set to zero | - |
| `AXI4STREAM_AUXM_TID_TDTEST_WIDTH` | The value of `ID_WIDTH` + `DEST_WIDTH` must not exceed 24 | - |