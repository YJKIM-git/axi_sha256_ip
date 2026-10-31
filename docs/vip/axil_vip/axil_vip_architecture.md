# AXI4-Lite UVM VIP Architecture & Developer Reference

본 문서는 VIP 유지보수 및 확장을 담당하는 엔지니어를 위한 아키텍처 및 내부 구조 명세서입니다.

## 1. Architectural Overview

본 VIP는 확장성과 재사용성을 극대화하기 위해 Siemens Verification Academy의 `apb_agent` 구조를 벤치마킹하여 설계되었습니다. 이에 따라 클래스 기반 UVM 컴포넌트와 핀 레벨 제어를 담당하는 BFM(Bus Functional Model)을 엄격히 분리한 Dual-Top 구조를 채택했습니다.

```bash
+-----------------------------------------------------------------------------+
|                             Sequence Library                                |
|                                                                             |
|  * Base: axi4lite_read_seq, axi4lite_write_seq                              |
|  * Util: axi4lite_sweep_seq, axi4lite_partial_write_seq                     |
|  * Test: axi4lite_protocol_cov_seq, axi4lite_err_inject_seq                 |
+-----------------------------------------------------------------------------+
                                      |
                                      v (axi4lite_seq_item)
+=============================================================================+
|                              axi4lite_agent                                 |
|                                                                             |
|  +--------------------+                     +--------------------+          |
|  | axi4lite_sequencer |==== seq_item =====> |  axi4lite_driver   |          |
|  +--------------------+                     +--------------------+          |
|                                                        | (Task Call)        |
|  +--------------------+                     +--------------------+          |
|  | axi4lite_coverage_ |<-------- ap --------|  axi4lite_monitor  |          |
|  |       monitor      |                     +--------------------+          |
|  +--------------------+                                ^ (Event/Data)       |
|            |                                           |                    |
+============|===========================================|====================+
             v (To Scoreboard/Env)                       |
                                                         |
+--------------------------------------------------------|--------------------+
|                      Virtual Interface Layer (BFM & IF)|                    |
|                                                        |                    |
|         +-------------------+                          |                    |
|         |  axi4lite_driver  |<-------------------------+                    |
|         |       _bfm        |                                               |
|         +-------------------+                                               |
|                   | (Pin Level Drive)                                       |
|                   v                                                         |
|         +-------------------+                                               |
|  DUT <==|    axi4lite_if    |==> SVA (Protocol Assertions)                  |
|         +-------------------+                                               |
|                   | (Pin Level Sample)                                      |
|                   v                                                         |
|         +-------------------+                                               |
|         | axi4lite_monitor  |--------------------------+                    |
|         |       _bfm        |                          |                    |
|         +-------------------+                          |                    |
+--------------------------------------------------------|--------------------+

```

## 2. UVM Components & Data Structure

### 2.1. Agent Configuration & Validation

* `axi4lite_agent`는 `build_phase` 단계에서 `axi4lite_agent_config` 객체를 로드합니다.
* 로딩된 `DATA_WIDTH` 값이 32 또는 64가 아닐 경우, UVM `build_phase`에서 `UVM_FATAL`을 발생시켜 시뮬레이션 초기화 단계의 구조적 오류를 차단합니다.

### 2.2. Sequence Item Static Allocation

* 트랜잭션 데이터 단위인 `axi4lite_seq_item` 내부의 `addr`, `wdata`, `rdata` 변수는 지원하는 최대 폭인 `logic [63:0]`으로 고정 할당되어 있습니다.
* 데이터 폭에 따른 클래스 파편화를 방지하고 다형성(Polymorphism) 관리를 단순화합니다.

## 3. BFM Layer Implementation

### 3.1. Driver BFM (`axi4lite_driver_bfm`)

* Write 트랜잭션 구동 시 AW 채널과 W 채널을 `fork-join` 블록을 사용하여 병렬로 제어합니다.
* `ignore_ready_timeout` 플래그가 비활성화된 상태에서 Ready 신호가 100 사이클 내에 수신되지 않으면 Timeout 에러를 발생시킵니다.

### 3.2. Monitor BFM & Masking (`axi4lite_monitor_bfm`)

* `monitor_write`와 `monitor_read` 태스크를 `fork-join`으로 실행하여 백그라운드에서 병렬 샘플링을 수행합니다.
* 물리적 AXI4-Lite interface 신호는 64-bit로 고정되어 있습니다. 설정된 논리 폭(`DATA_WIDTH`)이 32인 경우, `axi4lite_monitor`의 `notify_transaction` 함수에서 `wdata` 및 `rdata`에 한해 상위 32비트를 `64'h00000000FFFFFFFF`로 마스킹한 후 Analysis Port로 전달합니다. 주소, `WSTRB`, `PROT` 및 interface 자체의 물리 폭은 변경하지 않습니다.

## 4. Interface & SVA (`axi4lite_if`)

`axi4lite_if`는 `axi4lite_agent_config`에 정의된 `cfg_data_width`, `disable_alignment_sva`, `disable_timeout_sva` 값을 전달받아 인터페이스 내부의 검증 조건을 동적으로 제어합니다. 여기서 `DATA_WIDTH`는 물리적 interface 폭을 재구성하는 parameter가 아니라 32-bit 또는 64-bit 활성 프로토콜 폭을 지정하는 논리 설정입니다. 내장된 SVA는 ARM 사의 공식 검증 가이드라인인 "AMBA 4 AXI4, AXI4-Lite, and AXI4-Stream Protocol Assertions User Guide"를 기준으로 설계되었으며, VIP 구현 환경에 맞춘 지원 및 배제(Waiver) 항목은 다음과 같습니다.

### 4.1. Supported ARM Assertions

시뮬레이션 부하를 최소화하기 위해 동일한 검증 로직을 공유하는 신호들은 하나의 Assertion 블록으로 통합(Grouping) 구현되었습니다.

| Category | VIP Implemented SVA | ARM Official / Custom SVA Reference |
| :--- | :--- | :--- |
| **Reset**<br>(초기화 보장) | `p_min_reset_duration`<br>`p_valid_low_during_reset`<br>`p_valid_low_after_reset` | `[AMD UG1037]` Table 4-1 (16-cycle min reset)<br>`AXI4_ERRM_AW/W/ARVALID_RESET`, `AXI4_ERRS_B/RVALID_RESET`<br>`AXI4_ERRM_*VALID_X` (Post-reset deassertion) |
| **Unknown Check**<br>(X/Z 상태 방지) | `p_valid_not_unknown`<br>`p_ready_not_unknown`<br>`p_addr_not_unknown`<br>`p_prot_no_unknown`<br>`p_wstrb_no_unknown`<br>`p_wdata_lane_not_unknown`<br>`p_rdata_not_unknown` | `AXI4_ERRM_AW/W/ARVALID_X`, `AXI4_ERRS_B/RVALID_X`<br>`AXI4_ERRS_AW/W/ARREADY_X`, `AXI4_ERRM_B/RREADY_X`<br>`AXI4_ERRM_AWADDR_X`, `AXI4_ERRM_ARADDR_X`<br>`AXI4_ERRM_AWPROT_X`, `AXI4_ERRM_ARPROT_X`<br>`AXI4_ERRM_WSTRB_X`<br>`AXI4_ERRM_WDATA_X`<br>`AXI4_ERRS_RDATA_X` |
| **Stability**<br>(신호 유지) | `p_aw_stability`<br>`p_w_stability`<br>`p_ar_stability`<br>`p_r_stability`<br>`p_b_stability` | `AXI4_ERRM_AWADDR_STABLE`, `AXI4_ERRM_AWPROT_STABLE`, `AXI4_ERRM_AWVALID_STABLE`<br>`AXI4_ERRM_WDATA_STABLE`, `AXI4_ERRM_WSTRB_STABLE`, `AXI4_ERRM_WVALID_STABLE`<br>`AXI4_ERRM_ARADDR_STABLE`, `AXI4_ERRM_ARPROT_STABLE`, `AXI4_ERRM_ARVALID_STABLE`<br>`AXI4_ERRS_RDATA_STABLE`, `AXI4_ERRS_RRESP_STABLE`, `AXI4_ERRS_RVALID_STABLE`<br>`AXI4_ERRS_BRESP_STABLE`, `AXI4_ERRS_BVALID_STABLE` |
| **Protocol & Dependency**<br>(정렬 및 응답 의존성) | `p_addr_alignment_32`<br>`p_addr_alignment_64`<br>`p_addr_bounds`<br>`p_resp_no_exokay`<br>`p_bvalid_dependency`<br>`p_rvalid_dependency`<br>`p_write_one_to_one`<br>`p_read_one_to_one` | `AXI4LITE_AUX_DATA_WIDTH` (32-bit 4B alignment)<br>`AXI4LITE_AUX_DATA_WIDTH` (64-bit 8B alignment)<br>Custom (`cfg_addr_width` address boundary check)<br>`AXI4LITE_ERRS_BRESP_EXOKAY`, `AXI4LITE_ERRS_RRESP_EXOKAY`<br>`AXI4_ERRS_BRESP_AW`, `AXI4_ERRS_BRESP_WLAST`<br>`[ARM IHI0022]` Section A3.3.2 (Read response dependency)<br>`AXI4_ERRS_BRESP_ALL_DONE_EOS` (1:1 Write response count)<br>`AXI4_ERRS_RLAST_ALL_DONE_EOS` (1:1 Read response count) |
| **Timeout**<br>(지연 방지) | `p_aw_timeout`, `p_w_timeout`, `p_b_timeout`<br>`p_ar_timeout`, `p_r_timeout` | `AXI4_RECS_AWREADY_MAX_WAIT`, `AXI4_RECS_WREADY_MAX_WAIT`, `AXI4_RECM_BREADY_MAX_WAIT`<br>`AXI4_RECS_ARREADY_MAX_WAIT`, `AXI4_RECM_RREADY_MAX_WAIT` (100 cycles) |

### 4.2. Unsupported / N/A Assertions

해당 규격들은 AXI4-Lite 스펙상 발생하지 않는 조건이거나, 인터페이스 계층(SVA)이 아닌 상위 UVM 환경에서 검증하는 것이 타당하여 의도적으로 배제(Waiver)되었습니다.

* **Burst 속성 미지원 (AXI4-Lite 규격 외):** `AXI4_ERRS_RDATA_NUM`, `AXI4_AUX_MAXRBURSTS`, `AXI4_AUX_MAXWBURSTS`
  * **사유:** AXI4-Lite 프로토콜은 단일 전송(Single-beat) 전용 규격이므로 Burst 관련 데이터 검증 및 파라미터가 요구되지 않습니다.
* **Internal Logic Checks (CAM/Buffer 한계 점검):** `AXI4_AUX_RCAM_OVERFLOW`, `AXI4_AUX_WCAM_OVERFLOW` 등
  * **사유:** 트랜잭션 추적 버퍼(CAM) 상태를 점검하는 검증 IP 내부용 보조 지표입니다. 본 VIP는 카운터 변수(`outstanding_*_cnt`, `*_done_cnt`) 기반의 경량화 추적 구조를 사용하여 해당 로직이 불필요합니다.
* **WSTRB 복합 연산:** `AXI4_ERRM_WSTRB`
  * **사유:** Burst 파라미터를 기반으로 동적 WSTRB를 추적하는 연산 부하를 제거했습니다. 유효성은 시퀀스의 정합성 제약 조건(Constraint) 및 `p_wdata_lane_not_unknown`으로 대체 검증합니다.



## 5. RAL Integration (`reg2axi4lite_adapter`)

* `reg2axi4lite_adapter`는 `uvm_reg_bus_op` 통신을 `axi4lite_seq_item`으로 변환합니다.
* `axi4lite_agent_config.enable_random_delay`가 설정된 경우 트랜잭션 무작위화(`randomize()`)를 수행하여 채널 지연 시간을 할당하고, 설정되지 않은 경우 모든 지연 시간을 0으로 고정하여 안정적인 레지스터 접근을 보장합니다.

## 6. Protocol Coverage (`axi4lite_coverage_monitor`)

`axi4lite_coverage_monitor`는 AMBA AXI Protocol Specification (IHI0022)을 기준으로 지원하는 AXI4-Lite protocol space를 측정하도록 설계되었습니다. 타깃 DUT가 구조적으로 지원하지 않는 조건은 별도 waiver 대상으로 관리합니다. 세부적인 커버포인트 및 스펙 매핑 내역은 동봉된 `AXI4_Lite_Verification_Plan.xlsx`를 참조하시기 바랍니다.

### 6.1. Coverage Architecture

데이터 폭과 트랜잭션 유형에 따라 4개의 독립적인 커버리지 그룹으로 분리되어 동적 할당됩니다.

* **32-bit 환경:** `cg_axi4lite_32b_normal`, `cg_axi4lite_32b_error`
* **64-bit 환경:** `cg_axi4lite_64b_normal`, `cg_axi4lite_64b_error`

### 6.2. Cross Coverage Strategy

* **채널 독립성 검증 (`CROSS_AW_W_DELAY`):** Write 통신 시 AW(주소)와 W(데이터) 채널의 지연 시간을 교차하여, 두 채널의 독립적인 도착 타이밍 조합을 검증합니다. 이는 AXI4-Lite의 transaction ID 기반 out-of-order 응답 처리를 검증하는 항목은 아닙니다.
* **에러 응답 교차 (`CROSS_DIR_ERR_RESP`):** 방향(Read/Write)과 유효한 에러 응답(`SLVERR`, `DECERR`)이 정상적으로 반환되는지 교차 확인합니다.


## 7. Limitations & Exclusions

본 VIP는 경량화 및 실행 속도 최적화를 목적으로 아래의 기능은 지원하지 않습니다.

* **에러 복구 (Error Recovery):** DUT가 행(Hang)에 걸려 `ignore_ready_timeout`을 초과한 경우, 트랜잭션을 강제 취소하고 버스를 초기화하는 복구 메커니즘은 제공하지 않으며 즉시 `UVM_ERROR`를 반환합니다.
* **Multiple Outstanding Tracking:** 물리 계층(SVA) 내 카운터를 통한 1:1 응답 의존성은 검사하나, transaction ID 기반의 비순차적 다중 Outstanding 응답 검증은 AXI4-Lite의 지원 범위 밖이며 상위 Scoreboard 영역으로 위임합니다.

