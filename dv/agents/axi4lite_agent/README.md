
# AXI4-Lite UVM VIP User Guide

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

## 1. Overview (개요)

본 Verification IP(VIP)는 AMBA AXI4-Lite 프로토콜 사양을 준수하는 UVM 1.2 기반의 검증 컴포넌트입니다.

* **설계 배경 및 라이선스:** 본 프로젝트는 Siemens Verification Academy에서 제공하는 `apb_agent`의 구조를 벤치마킹하여 설계되었으며, 해당 아카데미의 라이선스 정책을 따릅니다.


* **오픈소스 툴체인 호환성:** 고가의 상용 툴(vsim 등)에 종속되지 않도록, Xilinx Vivado Simulator(xsim) 및 오픈소스 레지스터 맵 생성기인 PeakRDL 환경에서 테스트되었습니다.


* **동적 환경 지원:** 32-bit 및 64-bit 데이터 폭 환경을 지원하며, Configuration 객체를 통해 시뮬레이션 시점에 동적으로 설정할 수 있습니다.



## 2. Architecture (컴포넌트 구조)

VIP(`axi4lite_agent`)는 다음과 같은 핵심 UVM 컴포넌트들로 구성됩니다.

* **Monitor (`axi4lite_monitor`):** 버스 신호를 모니터링하여 `axi4lite_seq_item`으로 변환 및 브로드캐스트하며, 모드(`active`/`passive`)와 무관하게 항상 생성됩니다.


* **Driver & Sequencer (`axi4lite_driver`, `axi4lite_sequencer`):** `m_cfg.active` 설정이 `UVM_ACTIVE`일 때만 생성 및 연결되어 버스 마스터 역할을 수행합니다.


* **Coverage Monitor (`axi4lite_coverage_monitor`):** `m_cfg.has_functional_coverage`가 활성화된 경우에만 생성되어 Monitor의 Analysis Port와 연결되며, 프로토콜 검증 지표를 수집합니다.



## 3. Interface & SVA (`axi4lite_if.sv`)

물리적 버스 신호를 연결하는 인터페이스에는 프로토콜 위반을 즉각적으로 잡아내기 위한 SystemVerilog Assertions(SVA)가 강력하게 내장되어 있습니다.

* **주요 내장 검증 항목 (SVA):**
* **Reset 및 Unknown(X/Z) 상태 검증:** 리셋 최소 유지 시간(`p_min_reset_duration`), 리셋 중 신호 비활성화(`p_valid_low_during_reset`), 제어/데이터 신호의 X/Z 값 인가 방지(`p_valid_not_unknown`, `p_rdata_not_unknown` 등).


* **신호 안정성 (Stability):** Valid 신호가 인가된 후 Ready가 들어올 때까지 Address, Data, Strobe 등의 신호가 변하지 않는지 검사합니다 (`p_aw_stability`, `p_w_stability` 등).


* **프로토콜 준수 검증:** 주소 데이터 폭 정렬(`p_addr_alignment_32`), AXI4-Lite 규격상 금지된 `EXOKAY` 응답 발생 방지(`p_resp_no_exokay`), Write/Read 응답 의존성 검사(`p_bvalid_dependency`).


* **런타임 SVA 제어 플래그:** 에러 주입(Error Injection) 시나리오 테스트 시 의도적인 프로토콜 위반을 허용하기 위해, 인터페이스 내부의 `disable_alignment_sva`, `disable_timeout_sva` 변수를 통해 특정 SVA를 동적으로 비활성화할 수 있습니다.



## 4. Configuration (`axi4lite_agent_config`)

VIP를 테스트 벤치에 인스턴스화할 때 `uvm_config_db`를 통해 전달해야 하는 환경 설정 객체입니다.

* **구조적 파라미터:** `ADDR_WIDTH` (기본 32) 및 `DATA_WIDTH` (32 또는 64) 변수를 통해 버스 폭을 설정합니다. 이 값은 앞서 설명한 `axi4lite_if` 내부의 SVA 조건식과 연동됩니다.


* **제어 파라미터:** `active` 플래그, `has_functional_coverage` 플래그, 그리고 레지스터 모델 어댑터 사용 시 채널 지연 시간을 무작위로 인가할지 결정하는 `enable_random_delay` 플래그를 지원합니다.



## 5. Sequence Item (`axi4lite_seq_item`)

사용자가 시퀀호를 통해 발생시키는 개별 버스 트랜잭션 단위입니다. 기본 데이터 외에 네거티브(Negative) 테스트를 위한 강력한 **Error Injection Knobs**를 포함합니다.

* **기본 제어 변수:** 방향 `dir` (`WRITE` / `READ`), 주소 `addr`, 데이터 `wdata`, 스트로브 `wstrb`, 보호 유형 `prot`.


* **지연 제어 (Delay):** `aw_delay`, `w_delay`, `b_delay`, `ar_delay`, `r_delay` 변수를 통해 각 채널별 핸드셰이크 지연 시간을 0~20 사이로 무작위 할당합니다.


* **에러 주입 제어 (Error Injection Knobs):**
* `force_unaligned_addr`: AXI4-Lite 규격을 위반하는 비정렬 주소(Unaligned Address)를 강제로 주입하여 DUT의 에러 처리 능력을 검증합니다.


* `force_invalid_wstrb`: 데이터 폭에 맞지 않는 잘못된 바이트 활성화 신호(Write Strobe) 패턴을 발생시킵니다.


* `ignore_ready_timeout`: 의도적으로 타임아웃 예외를 발생시키거나 Ready 응답 대기 시간을 무시하도록 유도합니다.



## 6. Coverage Monitor (`axi4lite_coverage_monitor`)

환경 설정(`DATA_WIDTH`)에 따라 정상 및 에러 트랜잭션용 커버리지 그룹(`cg_axi4lite_32b_normal`, `cg_axi4lite_64b_error` 등)을 동적으로 인스턴스화하여 신뢰성 지표를 측정합니다.

* **주요 측정 항목 (Coverpoints):**
* `DIR` & `RESP`: 읽기/쓰기 동작과 응답(`OKAY`, `SLVERR`, `DECERR`) 비율을 측정합니다. *(참고: 예제로 제공된 DUT는 `DECERR` 발생 기능이 없으므로 해당 Bin은 `ignore_bins` 처리됨)*.


* `WSTRB`: Write Strobe 신호의 극단값(`all_zeros`, `all_ones`) 및 바이트 단위의 부분 쓰기(`partial`) 여부를 확인합니다.


* `PROT`: Secure 및 Privilege 모드에 대한 8가지 접근 권한 조합(예: `unpriv_secure_data` 등)이 모두 타격되었는지 검증합니다.


* `ALIGN`: 데이터 폭에 맞는 주소 정렬(`aligned`) 상태 및 에러 환경에서의 비정렬(`unaligned`) 주소 인가 여부를 확인합니다.


* `DELAY`: AW, W, B, AR, R 각 채널의 지연 시간이 없는 경우(`back_to_back`)와 지연된 경우(`delayed`)를 교차(Cross) 검증합니다. *(참고: 파이프라인 지연이 필수인 DUT 특성을 반영하여 불가능한 0-cycle 응답은 `ignore_bins` 처리됨)*.



## 7. Sequence Library API

VIP에서 기본으로 제공하여 사용자가 Test 단계에서 즉시 활용할 수 있는 시퀀스 목록입니다.

* **Base Sequences:** 단일 쓰기(`axi4lite_write_seq`) 및 단일 읽기(`axi4lite_read_seq`)를 수행합니다.


* **`axi4lite_partial_write_seq`:** 특정 바이트만 선별적으로 기록할 때 사용합니다. `wstrb`를 `8'h00` 초과 `8'hFF` 미만으로 제약하여 부분 쓰기를 수행합니다.


* **`axi4lite_sweep_seq`:** `start_addr`부터 `end_addr`까지 순차적으로 4 또는 8 바이트(`stride`)씩 증가시키며 Write 후 곧바로 Read를 수행하는 메모리 검증용 루프 시퀀스입니다.


* **`axi4lite_protocol_cov_seq`:** 커버리지 100% 타격을 위해 특정 `addr`, `wstrb`, 및 채널 `delay` 조건을 정교하게 강제하는 하드코딩된 유틸리티 시퀀스입니다.



## 8. Limitations & Future Works

* 현재 구현된 VIP는 기본적인 트랜잭션 구동 및 커버리지 측정에 최적화되어 있으나, 복잡한 런타임 에러 복구(Error Recovery) 메커니즘 등 고급 UVM 기능은 기초적인 수준으로 지원합니다.


* 추후 상용 VIP 검증 환경에 대한 벤치마킹을 바탕으로 코너 케이스(Corner Case) 발굴 로직 및 더욱 정교한 `Error Injection` 시나리오가 지속적으로 개선 및 추가될 예정입니다.



### 9. User Guide & Best Practices

본 VIP를 타겟 검증 환경에 통합(Integration)하고 활용할 때, 원본 코드를 직접 수정하는 것을 지양하고 아래의 권장 방식에 따라 제어하는 것을 원칙으로 합니다.

#### 9.1. VIP 제어 원칙 (Configuration & Sequence)

VIP의 동작은 철저하게 정적 설정(Config)과 동적 제어(Sequence)로 분리하여 다루어야 합니다.

* **구조 및 동작 모드 제어 (`axi4lite_agent_config`):**
데이터 폭(32/64-bit), 모니터링 전용 모드(`UVM_PASSIVE`), 커버리지 수집 활성화 여부 등 VIP가 빌드(`build_phase`)될 때 결정되어야 하는 구조적 설정은 반드시 `axi4lite_agent_config` 객체를 통해 제어해야 합니다.


* **트랜잭션 및 에러 주입 제어 (Sequence & Knobs):**
시뮬레이션 구동 중 발생하는 타이밍(Delay) 조절이나 프로토콜 위반(Error Injection)은 인터페이스나 드라이버를 직접 건드리지 않고, `axi4lite_seq_item` 내부에 마련된 제어 변수(Knobs)를 `randomize() with` 구문으로 제약하여 발생시켜야 합니다.



#### 9.2. UVM RAL (Register Abstraction Layer) 연동 가이드

레지스터 모델을 사용하는 환경을 위해 VIP 내부에 `reg2axi4lite_adapter`가 내장되어 있습니다.

* **동작 방식:** UVM RAL의 표준 버스 트랜잭션(`uvm_reg_bus_op`)을 AXI4-Lite 규격에 맞는 `axi4lite_seq_item`으로 변환하며, 응답 결과를 다시 RAL로 반환합니다.


* **랜덤 지연 활성화 (`enable_random_delay`):** 기본적으로 어댑터를 통한 레지스터 접근은 지연 시간(Delay)이 0으로 설정됩니다. 하지만 `axi4lite_agent_config.enable_random_delay = 1`로 설정할 경우, 레지스터 읽기/쓰기 시에도 채널별로 무작위 지연 시간이 인가되어 실제 버스 트래픽과 유사한 스트레스 환경을 구성할 수 있습니다.



#### 9.3. Coverage Monitor 예외(Waiver) 처리 가이드

VIP에 내장된 `axi4lite_coverage_monitor`는 프로토콜 규격을 기반으로 작성되었으므로 100% 커버리지를 요구합니다. 하지만 타겟 DUT의 하드웨어적 한계로 인해 절대 달성 불가능한 항목이 발생할 수 있습니다.

* **Waiver 권장 방식:** 이 경우 VIP 원본 코드를 임의로 삭제하지 마십시오. 대신 사용자의 검증 환경에 맞춰 `ignore_bins`를 적용하거나, `option.weight = 0`을 할당하여 해당 커버포인트를 모수에서 깔끔하게 제외(Waiver)하는 방식을 권장합니다. 단 xsim의 경우, `option.weight = 0`을 2025.2버전에서는 지원하지 않았으므로, `ignore_bins`를 활용하는 것이 가장 안전합니다.


* *예시:* DUT가 구조적으로 0-Cycle 응답을 지원하지 못한다면, 지연 시간 측정 항목(`B_DELAY`, `R_DELAY`)에서 `back_to_back` 조건을 `ignore_bins`로 덮어씌워 처리합니다.


* **프로토콜 커버리지 (`axi4lite_coverage_monitor.svh`) 적용 사례:**
* `ERR_RESP` 커버포인트: DUT가 주소 디코드 에러(DECERR)를 지원하지 않으므로 `decerr (2'b11)`을 `ignore_bins`로 제외. 


* `B_DELAY`, `R_DELAY` 커버포인트: 버퍼를 거치는 DUT 순차 논리(always_ff) 특성상 핸드셰이크 직후 0사이클(Wait State 0) 응답이 불가하므로 `back_to_back` 조건 제외.





**적용 코드 스니펫 (`axi4lite_coverage_monitor.svh`)**

```systemverilog
  // ... (중략) ...
  B_DELAY: coverpoint txn.b_delay iff (txn.dir == axi4lite_seq_item::WRITE) {
    //bins back_to_back = {0}; bins delayed = {[1 : 20]};
    ignore_bins back_to_back = {0}; bins delayed = {[1 : 20]};   // Not supported in this DUT
  }

  // ... (중략) ...

  R_DELAY: coverpoint txn.r_delay iff (txn.dir == axi4lite_seq_item::READ) {
    //bins back_to_back = {0}; bins delayed = {[1 : 20]};
    ignore_bins back_to_back = {0}; bins delayed = {[1 : 20]};   // Not supported in this DUT
  }

  // ... (중략) ...

covergroup cg_axi4lite_32b_error with function sample (axi4lite_seq_item txn);
  // ... (중략) ...
  ERR_RESP: coverpoint txn.resp {
    bins slverr = {2'b10};
    //bins decerr = {2'b11};
    ignore_bins decerr = {2'b11}; // Not supported in this DUT
  }
  // ... (중략) ...

```

### 9.4. Example Tests (`example_test` 폴더 참조)

본 VIP 패키지의 `example_test` 폴더에는 VIP의 실제 통합 및 제어 방식을 직관적으로 파악할 수 있도록 4개의 레퍼런스 파일이 동봉되어 있습니다. 신규 검증 환경을 구축할 때 이 파일들을 템플릿으로 활용하는 것을 권장합니다.

* **`example_csr_map_test_base.svh` (VIP 환경 설정의 뼈대)**
최상위 테스트 클래스들의 부모 클래스(Base)로, VIP 인스턴스화의 표준 방법을 보여줍니다. `uvm_config_db`를 통해 가상 인터페이스(`vif`)와 BFM(`mon_bfm`, `drv_bfm`)을 가져오고, `axi4lite_agent_config`를 생성하여 데이터 폭이나 SVA 제어 플래그(`disable_alignment_sva`, `disable_timeout_sva`) 등을 초기 세팅하는 과정을 포함합니다.


* **`example_csr_map_err_test.svh` (Error Injection 제어 시연)**
VIP에 내장된 에러 주입 시퀀스(`axi4lite_err_inject_seq`)의 활용법을 제시합니다. 네거티브(Negative) 테스트를 위해 해당 시퀀스를 RAL 모델의 기본 시퀀서(`default_map.get_sequencer()`)를 통해 구동(`start`)하고, 강제로 규격 위반 트랜잭션을 발생시키는 시나리오 작성법을 시연합니다.


* **`example_csr_map_protocol_test.svh` (Config 덮어쓰기 및 스트레스 테스트 시연)**
`build_phase`에서 VIP 내부 파라미터인 `enable_random_delay`를 `1`로 동적으로 변경(Override)하는 방법을 확인할 수 있습니다. 또한, 프로토콜 커버리지를 극대화하기 위한 하드코딩 유틸리티 시퀀스인 `axi4lite_protocol_cov_seq`를 구동하는 구조를 제공합니다.


* **`example_csr_map_test_pkg.sv` (Test Package 래핑)**
앞서 언급된 모든 테스트 클래스 파일(`test_base.svh`, `err_test.svh`, `protocol_test.svh` 등)을 하나의 UVM 패키지로 묶어 관리하는 역할을 합니다. 이를 통해 최상위 테스트벤치(`hvl_top` 등)에서 패키지 임포트(`import example_csr_map_test_pkg::*;`)만으로 모든 테스트 클래스에 접근할 수 있도록 구성하는 방법을 제시합니다.



```
