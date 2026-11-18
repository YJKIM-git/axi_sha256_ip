# Verification Specification
# UVM 1.2 Block-Level Verification Environment for SHA-256 IP Core

# 1. Introduction & Verification Strategy

## 1.1 Purpose & Scope
본 문서는 NIST FIPS 180-4 표준 기반 SHA-256 하드웨어 가속기(`sha256_axi_wrapper` 및 `sha256_core`)의 블록 레벨(Block-level) 검증 사양서입니다.

* **Target DUT:** AXI4-Lite 제어 인터페이스, AXI4-Stream 데이터 인터페이스, 하드웨어 패딩 FSM을 포함하는 `sha256_axi_wrapper`와 67사이클 고정 지연 압축 연산을 수행하는 `sha256_core`를 대상으로 합니다. (하드웨어 사양은 `Micro_Architecture_Specification.md` 참조)
* **Verification Scope:** RTL 시뮬레이션 환경에서 버스 프로토콜 준수 여부, CSR 접근 제어 및 보호 로직, 하드웨어 자동 패딩, 해시 연산 결과의 정합성을 검증합니다. Zynq PS 및 AXI DMA를 연동한 펌웨어 통합 테스트는 FPGA 환경에서 별도 수행하므로 본 문서의 범위에서 제외합니다.

## 1.2 Verification Methodology
본 검증 환경은 UVM 1.2를 기반으로 구축되었으며, 적용된 검증 기법은 다음과 같습니다.

1. **Dual-Top Architecture (UVM 1.2):** Siemens Verification Academy의 가이드라인을 확장 적용하여, 핀 레벨 신호를 구동 및 샘플링하는 HDL 계층(`hdl_top`, BFM)과 트랜잭션 객체를 처리하는 HVL 계층(`hvl_top`, UVM Class)을 엄격히 분리하여 구성합니다.
2. **PeakRDL 기반 RAL (Register Abstraction Layer):** PeakRDL은 표준 레지스터 기술 언어인 SystemRDL(`sha256_csr.rdl`)을 통해 UVM RAL 코드(`sha256_reg_pkg.sv`)를 자동 생성하는 오픈소스 툴체인입니다. 생성된 RAL을 통해 물리 주소 대신 레지스터 및 필드 단위로 추상화된 접근 제어를 수행하며, 버스 모니터와 연결된 Explicit Predictor(`uvm_reg_predictor`)를 통해 DUT 레지스터의 미러 값을 추적하고 `sha256_scoreboard`에서 필드 권한(`get_access()`) 기반의 버스 응답 자동 채점을 수행합니다.
3. **DPI-C Reference Model 연동:** C++ 로 구현된 SHA-256 알고리즘 함수(`c_sha256_digest`)를 DPI-C 인터페이스를 통해 `sha256_scoreboard`에 연동합니다. 시뮬레이션 중 수집된 입력 스트림과 초기 해시 상태를 C++ Reference 모델로 전달하여 기댓값을 산출하고, 이를 DUT의 해시 연산 결과와 대조하여 데이터 무결성을 자동 검증합니다.
4. **ABV (Assertion-Based Verification):** 인터페이스 내부의 ARM 표준 프로토콜 SVA(`axi4lite_if`, `axis_if`)와 DUT 내부 신호에 `bind`된 White-box SVA(`sha256_wrapper_sva`, `sha256_core_sva`)를 통해 Test Plan의 SVA 항목을 검증합니다.
5. **Verification Process:** 검증 완료 지표를 SVA, Coverage, Test Result(Scoreboard 및 Sequence)로 분류하여 관리합니다. Test Result에 명시한 Sequence 항목에 대해 1차 테스트를 구성하고, 커버리지 리포트(`xcrg`) 분석을 통해 식별된 미달성 Functional Coverage와 Code Coverage(Branch, Condition, Toggle)에 대해 CDV(Coverage-Driven Verification)를 진행합니다. 이후 남은 도달 불가한 항목에 대해 Waiver 처리를 통해 검증을 완료합니다.
6. **Simulation Toolchain & `xsim` Compatibility Design:** 본 검증 환경은 **Xilinx Vivado Simulator (`xsim v2025.2`)**를 타겟 시뮬레이터로 사용하며, DPI-C 컴파일러(`xsc`), 커버리지 병합 리포터(`xcrg`), 오픈소스 레지스터 생성기(`PeakRDL`)를 표준 툴체인으로 연동합니다. 단 `xsim`의 SystemVerilog 및 Coverage 엔진의 미지원 기능을 우회하기 위해, 런타임 `option.weight` 제어 대신 명시적 `ignore_bins` 및 조건부 Coverpoint를 사용하고, 복잡한 중첩 인라인 제약(`randomize() with { if ... }`) 대신 기본 제약과 사후 절차적 보정을 결합하여 시뮬레이터 안정성을 보장합니다.

## 1.3 Verification Categories (5 Domains)

UVM 검증 범위를 4개의 독립 컴포넌트 도메인(`AXI4-Lite`, `AXI4-Stream`, `Core`, `CSR`)과 1개의 복합 통합 도메인(`Overall`)으로 분할하여 테스트 플랜(`Verification_Plan.xlsx`)을 구성합니다. 단, UVM VIP 제약이나 RTL 시뮬레이션 시간 제약으로 인해 블록 레벨 UVM 환경에서 Waiver 처리된 항목들을 최종 Sign-off하기 위한 핀 레벨 정적 테스트벤치(`[DIR-01]~[DIR-03]`) 및 FPGA 시스템 레벨 검증 항목(`[FPGA-01]~[FPGA-09]`)은 `Verification_Plan.xlsx`의 `direct` 시트에서 별도로 관리합니다.

| Category | Target Scope | Checking & Coverage Mechanism |
| :--- | :--- | :--- |
| **1. AXI4-Lite** | `s_axi_*` Bus | `axi4lite_if` (SVA), `axi4lite_coverage`, `Scoreboard` (CSR Resp Check) |
| **2. AXI4-Stream** | `s_axis_*` Bus | `axis_if` (SVA), `axis_coverage`, `axis_monitor` (EOS Check) |
| **3. Core** | `sha256_core` | `core_monitor`, `core_if` & `sha256_core_sva`, `core_coverage`, `Scoreboard` (DPI-C) |
| **4. CSR** | Wrapper CSRs | RAL Explicit Predictor & Built-in Seq, `Scoreboard` (CSR Resp Check),<br>`sha256_csr_vseq`, `sha256_wrapper_sva` & `intr_bfm`, `sha256_csr_coverage` |
| **5. Overall** | Top-Level | `Scoreboard` (DPI-C & CSR Resp Check), `sha256_overall_vseq`,<br>`sha256_wrapper_sva`, `sha256_overall_coverage` |

**Primary Verification Focus**

* **1. AXI4-Lite (`s_axi_*` Bus):** AXI4-Lite VIP(`axi4lite_agent`)에 정의된 프로토콜 규약 준수 여부를 독립 검증. 채널별(AW/W/B/AR/R) 핸드셰이크 딜레이, 스트로브 및 보호 속성 조합, 프로토콜 에러 주입을 확인.
* **2. AXI4-Stream (`s_axis_*` Bus):** AXI4-Stream VIP(`axis_agent`)에 정의된 프로토콜 규약 준수 여부를 독립 검증. 핸드셰이크 딜레이 및 Back-pressure, 단일/버스트 패킷 경계, 유효 `tkeep` 및 데이터 패턴, 전송 중 리셋 처리를 확인.
* **3. Core (`sha256_core`):** 비정상 입력에 대한 보호 로직은 상위 Wrapper가 담당한다는 설계 분담 하에, 패딩이 완료된 유효 512-bit 블록 입력을 전제로 코어 단독 동작을 검증. 입출력 제어 핸드셰이크, FSM 및 67사이클 고정 레이턴시, 512-bit 데이터패스 스트레스 패턴 및 블록 체이닝, 전 사이클(`0~66`) 리셋 및 복구를 확인.
* **4. CSR (Wrapper CSRs):** 코어 해시 연산과 분리하여 Wrapper 내부의 CSR 제어 및 예외 보호 로직을 단독 검증. 레지스터 리셋 초기값, 접근 속성(`RO/RW/WO/W1C/W1P`) 및 단일 클록 펄스 자동 소멸, 비정렬 주소/미할당 주소/권한 위반 에러 응답(`SLVERR`/`DECERR`) 및 읽기 제로 마스킹, 연산 중 상태 변경 차단(Atomicity), 비보안 접근 차단(PROT Firewall), 인터럽트를 확인.
* **5. Overall (Top-Level E2E):** 스트림 수신부터 해시 산출까지 컴포넌트 간 상호작용으로 발생하는 복합 시나리오를 통합 검증. 하드웨어 자동 패딩(단일/다중 블록 경계 조건, `All-0x80` 데이터 경계, 비트 길이 누적), Little-to-Big Endian 변환, 블록 모드×바이트 정렬 교차, Auto/Manual Chaining(Custom IV), 코어 연산과 후속 블록 수신/패딩의 병렬(Overlap) 처리 및 연속 기동, 제어 비트 비활성화(`EN`, `IRQ_EN`), 비정상 `TKEEP` 하드웨어 차단 및 복구, 데이터 기아(Starvation) 및 코어 Busy 중 `SOFT_RESET` 복구를 확인.

## 1.4 Sign-off Criteria

본 IP의 Sign-off 기준은 다음과 같습니다.

* **Test Result (UVM Log & Scoreboard/RAL Check):** 전체 6종 테스트 스위트(`sanity`, `axil`, `axis`, `core`, `csr`, `overall`) 실행 시 UVM 시뮬레이션 로그 상 `UVM_WARNING`, `UVM_ERROR`, `UVM_FATAL` 발생 0건 달성. 모든 해시 연산 트랜잭션에 대한 `sha256_scoreboard`(DPI-C Reference Model) 비교 일치, AXI4-Lite 버스 응답 상시 검증, 그리고 RAL 내장 시퀀스(`uvm_reg_hw_reset_seq`, `uvm_reg_bit_bash_seq`) 통과를 UVM 로그 리포트로 확인.
* **Assertion (SVA Status):** 시뮬레이션 전 구간에서 인터페이스 내장 프로토콜 SVA 및 내부 White-box SVA 위반(`Assertion failed`) 발생 0건.
* **Coverage (Functional & Code Coverage):**
  * **Functional Coverage (100%):** 5대 검증 도메인에 정의된 모든 활성 Covergroup 및 Cross Coverage 병합(`xcrg`) 기준 100% 달성. (DUT 구조적 제약으로 도달 불가능한 조합은 `ignore_bins` 및 Waiver로 모수에서 제외함.)
  * **Code Coverage (Condition 100% & Uncovered Waiver Verification):** RTL 설계 모듈(`design/`) 대상 Condition 커버리지 100% 달성 및 도달 가능한(Reachable) 유효 Branch·Toggle 검증. 합성 안전성 확보용 FSM `default` 분기, 아키텍처 제약 비트(`msg_len`), 시뮬레이터(`xsim`)의 계측 오류로 인한 미달성 항목은 Waiver 사유서에 서술함.

## 1.5 Directory Structure

전체 프로젝트 디렉토리는 RTL 설계(`design/`), 문서(`docs/`), UVM 및 정적 검증 환경(`dv/`), FPGA 구현(`fpga/`), 그리고 SystemRDL 레지스터 명세(`rdl/`)로 분리되어 관리됩니다.

```text
sha256/
├── Makefile                           # UVM 시뮬레이션, 커버리지 병합(xcrg) 및 디렉토리 관리용 루트 Makefile
├── design/                            # 검증 대상 RTL 설계 소스
│   ├── sha256_axi_wrapper.sv          # Top Wrapper (AXI4-Lite CSR, AXI4-Stream 수신, 하드웨어 패딩 FSM)
│   └── sha256_core/                   # SHA-256 67사이클 압축 연산 코어 및 서브모듈
├── docs/                              # 하드웨어 및 검증 문서
│   ├── MAS/                           # Micro Architecture Specification 및 다이어그램/파형
│   ├── Verif_Spec/                    # Verification Specification
│   ├── Verification_Plan.xlsx         # 5대 도메인 통합 Test Plan 및 Waiver 사유서
│   ├── Verif_report/                  # UVM Block-Level Verification Sign-off Report
│   ├── FPGA_report/                   # Zynq-7000 FPGA Verification & PPA Analysis Report
│   └── vip/                           # VIP 전용 개발 명세서 및 User Guide (axil_vip, axis_vip)
├── dv/                                # 블록 레벨 검증 환경 (UVM 1.2 & Directed Static TB)
│   ├── agents/                        # 재사용 가능한 인터페이스별 UVM VIP 및 Passive Agent
│   │   ├── axi4lite_agent/            # AXI4-Lite Master VIP
│   │   ├── axis_agent/                # AXI4-Stream VIP
│   │   └── core_agent/                # SHA-256 Core 내부 신호 관찰용 Passive Agent 및 Coverage
│   ├── bl_tb/                         # SHA-256 UVM 블록 레벨 통합 테스트벤치
│   │   ├── env/                       # Top Env, Env Config, Scoreboard, Overall Coverage
│   │   ├── ref_model/                 # DPI-C 연동 C++ SHA-256 Golden Ref-Model
│   │   ├── register_model/            # PeakRDL 생성 RAL 패키지 및 CSR Coverage
│   │   ├── sequences/                 # Virtual Sequence Library
│   │   ├── tb/                        # Dual-Top 모듈 (hdl_top, hvl_top) 및 White-box SVA (Wrapper/Core)
│   │   └── test/                      # UVM Test 클래스 패키지
│   ├── static_tb/                     # VIP/DMA 제약 보완용 핀 레벨 정적 테스트벤치
│   │   └── tb_sha256_tkeep.sv         # TKEEP=4'b0000 (Null Beat) 및 27종 비정상 TKEEP 전수 검증 TB
│   └── utils/                         # 비동기 제어 유틸리티 (interrupt/, reset/ BFM 및 Util 클래스)
├── fpga/                              # Zybo Z7-20 FPGA 합성 스크립트(script/), 제약조건(synth/) 및 PS 펌웨어(firmware/)
└── rdl/                               # PeakRDL 기반 RAL 자동 생성용 SystemRDL 소스 (sha256_csr.rdl)
```

# 2. UVM Testbench Architecture

## 2.1 Dual-Top Architecture & White-Box Signal Binding (`hdl_top` & `hvl_top`)

본 테스트벤치는 시뮬레이션 계층을 물리적 핀 신호 제어 영역(`hdl_top`)과 트랜잭션 추상화 계층(`hvl_top`)으로 분리한 Dual-Top 구조를 채택합니다.

* **`hvl_top` (`tb/hvl_top.sv`):** 신호 타이밍이 배제된 추상화 계층을 담당합니다. `uvm_pkg` 및 `sha256_test_pkg`를 임포트하고 `run_test()`를 호출하여 객체 지향 기반의 UVM 테스트, 환경(`sha256_env`), 시퀀스를 구동합니다.
* **`hdl_top` (`tb/hdl_top.sv`):** 사이클 단위의 물리 신호 계층을 담당합니다. 100MHz 시스템 클록을 생성하고 DUT(`sha256_axi_wrapper`), Agent(`axi4lite_agent`, `axis_agent`, `core_agent`) 및 Utility(`INTR_UTIL`,`RESET_UTIL`)을 연결합니다.

### 2.1.1 Physical Interface & BFM Instantiation

`hdl_top`에 배치된 인터페이스와 BFM 모듈의 인스턴스 매핑 및 DUT 핀 연결 특성은 다음과 같습니다.

| 논리 경로 | Interface 인스턴스 | BFM 인스턴스 |
| --- | --- | --- |
| **AXI4-Lite** | `AXI4LITE` (`axi4lite_if`) | `AXI4LITE_drv_bfm`, `AXI4LITE_mon_bfm` |
| **AXI4-Stream** | `AXIS` (`axis_if`) | `AXIS_drv_bfm`, `AXIS_mon_bfm` |
| **Core (Passive)** | `CORE` (`core_if`) | `CORE_mon_bfm` |
| **Interrupt** | - | `INTR_bfm` (`intr_bfm`) |
| **Reset** | - | `RST_bfm` (`rst_bfm`) |

**Interface & BFM Connection Details**

* **AXI4-Lite (`AXI4LITE`, `AXI4LITE_drv_bfm`, `AXI4LITE_mon_bfm`):** DUT의 AXI4LITE 인터페이스를 연결하며, 가변 폭 VIP 이식을 위해 DUT 할당 핀 외의 상위 비트는 Zero-Padding합니다.
* **AXI4-Stream (`AXIS`, `AXIS_drv_bfm`, `AXIS_mon_bfm`):** DUT의 AXI4STREAM 인터페이스를 연결하며, 가변 폭 VIP 이식을 위해 DUT 할당 핀 외의 상위 비트는 Zero-Padding합니다.
인터페이스(`axis_if`)에는 SVA 관측을 위해 시스템 리셋(`rst_n_i`)을 연결하고, `AXIS_drv_bfm`과 `AXIS_mon_bfm`에는 `DUT.core_rst_n`을 연결하여 하드웨어 리셋, `SOFT_RESET`, 또는 `TKEEP` 위반 발생 시 BFM 내부 큐가 자동으로 플러시되도록 동기화합니다.
* **Core Passive (`CORE`, `CORE_mon_bfm`):** DUT 내부 압축 연산 모듈(`u_core`) 관측 전용이며, `SOFT_RESET` 및 Stream 에러 발생 시 모니터 상태를 동기화하기 위해 `DUT.core_rst_n`을 연결합니다.
* **Interrupt (`INTR_bfm`):** DUT의 완료 인터럽트 출력 핀(`irq_o`)을 감지합니다.
* **Reset (`RST_bfm`):** 시스템 비동기 리셋(`rst_n_i`) 구동 및 클록 사이클 동기화 대기를 담당합니다.

### 2.1.2 White-Box Signal Hooking & SVA Binding

외부 핀으로 노출되지 않는 내부 상태 머신(FSM)과 파이프라인 동작을 검증하기 위해 `hdl_top`에서 두 가지 White-box 접근 방식을 사용합니다.

1. **Core Interface Hooking (`assign`):** `DUT.u_core`의 입출력(`start_i`, `ready_o`, `busy_o`, `done_o`, `block_i`, `state_in_i`, `state_out_o`), 내부 컨트롤러(`u_controller`)의 제어 신호(`init_o`, `load_block_o`, `round_en_o`, `update_o`, `round_idx_o`), 그리고 Wrapper의 `first_block` 신호를 `CORE` 인터페이스에 연결하여 `CORE_mon_bfm`이 샘플링하도록 구성합니다.
2. **SVA Module Binding (`bind`):** RTL 원본 코드를 수정하지 않고 SystemVerilog `bind` 구문을 사용하여 `DUT`에 `sha256_wrapper_sva`를, `DUT.u_core`에 `sha256_core_sva`를 각각 연결합니다.

### 2.1.3 Top-Level Architecture Diagram

![Top-Level Architecture Diagram](figures/Top_Arch_2_1_3.png)
전체 검증 환경의 `hvl_top`(트랜잭션 추상화 계층)과 `hdl_top`(물리 신호 계층) 간의 구조 및 인터페이스는 다음과 같습니다. (각 Agent의 내부 세부 구조는 3장에서 별도로 기술합니다.)

## 2.2 Environment Topology & Configuration (`sha256_env` & `sha256_env_config`)

### 2.2.1 Component Hierarchy

최상위 검증 환경인 `sha256_env`는 3개의 Agent, RAL Predictor/Adapter, Scoreboard, 그리고 2개의 DUT 레벨 Coverage 컴포넌트로 구성됩니다.

```text
uvm_test_top (sha256_test_base 파생 클래스)
└─ m_env : sha256_env
   ├─ m_axi4lite_agent : axi4lite_agent
   │  ├─ m_driver       : axi4lite_driver           (active == UVM_ACTIVE)
   │  ├─ m_sequencer    : axi4lite_sequencer        (active == UVM_ACTIVE)
   │  ├─ m_monitor      : axi4lite_monitor
   │  └─ m_fcov_monitor : axi4lite_coverage (has_functional_coverage == 1)
   ├─ m_axis_agent : axis_agent
   │  ├─ m_driver       : axis_m_driver             (is_active == UVM_ACTIVE && is_master == 1)
   │  ├─ m_sequencer    : uvm_sequencer#(axis_seq_item)
   │  ├─ m_monitor      : axis_monitor
   │  └─ m_fcov_monitor : axis_coverage             (has_functional_coverage == 1)
   ├─ m_core_agent : core_agent
   │  ├─ monitor        : core_monitor
   │  └─ coverage       : core_coverage             (has_coverage == 1)
   ├─ m_reg2axi4lite           : reg2axi4lite_adapter
   ├─ m_axi4lite2reg_predictor : uvm_reg_predictor#(axi4lite_seq_item)
   ├─ m_scoreboard             : sha256_scoreboard       (has_scoreboard == 1)
   ├─ m_csr_coverage           : sha256_csr_coverage     (has_functional_coverage == 1)
   └─ m_overall_coverage       : sha256_overall_coverage (has_functional_coverage == 1)


```

### 2.2.2 Configuration Delivery Flow

BFM 핸들 및 환경 설정 객체(`sha256_env_config`)는 초기화 단계에서 다음 3단계를 거쳐 하위 컴포넌트에 전달됩니다.

1. **HDL Interface Registration (`hdl_top::initial`):**
   * 8개 Virtual Interface(`*_if.sv`, `*_bfm.sv`)를 `uvm_config_db`(`"uvm_test_top"` 범위)에 등록합니다.
2. **Top Config Assembly & Distribution (`sha256_test_base::build_phase`):**
   * RAL 블록(`csr_rb`)을 생성하고 `build()` 및 `lock_model()`을 수행합니다.
   * `uvm_config_db`에서 BFM 핸들을 조회하여 각 Agent Config 및 Utility에 바인딩합니다.
   * Agent 기본 파라미터를 설정합니다 (`AXIL`: 32-bit, Active / `AXIS`: Master, Active).
   * 통합 설정 객체(`m_env_cfg`)에 하위 Config, RAL, Utility 핸들을 할당하고 `uvm_config_db`(`"*"` 범위)에 등록합니다.
3. **Sub-Component Config Deployment (`sha256_env::build_phase`):**
   * `sha256_env_config::get_config()`를 호출하여 `m_cfg`를 로드합니다.
   * 각 Agent Config를 하위 경로로 재배포한 후 Agent, Scoreboard, Coverage 컴포넌트를 생성합니다.



### 2.2.3 Environment Control Parameters (`sha256_env_config`)

`sha256_env_config`는 하위 Agent 설정 객체와 RAL/Utility 핸들 외에 최상위 환경 레벨 컴포넌트의 동작을 제어하는 3개의 스위치 변수를 포함합니다.

* **`has_scoreboard` (기본값 `1`):** `1`일 때 `sha256_scoreboard`를 생성하고 Agent Monitor와의 TLM FIFO 연결을 수행합니다.
* **`has_functional_coverage` (기본값 `1`):** `1`일 때 환경(Env) 레벨 커버리지 컴포넌트인 `sha256_csr_coverage`와 `sha256_overall_coverage`를 생성하고 TLM 연결을 활성화합니다. (단, 각 Agent 내부에 존재하는 3개의 프로토콜/코어 커버리지인 `axi4lite_coverage`, `axis_coverage`, `core_coverage`는 연동되지 않으며, 각 Agent Config 객체의 flag를 통해 개별 제어됩니다.)
* **`enable_sb_check` (기본값 `1`):** Scoreboard가 생성된 상태에서 AXI4-Stream 입력 바이트 적재(`process_axis_data`) 및 AXI4-Lite `DIGEST_0~7` Read에 따른 DPI-C 해시 채점 로직의 실행 여부를 제어합니다 (단, RAL 기반 AXI4-Lite CSR 응답 검증인 `check_axil_response()`는 본 변수와 무관하게 전 구간 상시 동작합니다). 해시 값을 비교하지 않는 `axil`, `axis`, `csr` 테스트에서는 `0`으로 설정하며, `sanity`, `core`, `overall` 테스트에서는 전 구간 `1`로 유지합니다.

## 2.3 End-to-End TLM Connection & Transaction Flow

`sha256_env::connect_phase`에서는 각 Agent Monitor의 Analysis Port(`ap`)를 하위 검증 컴포넌트들로 Broadcast합니다.

| Source Analysis Port | Target Analysis Export / FIFO | Transaction Processing Role |
| :--- | :--- | :--- |
| **`m_axi4lite_agent.ap`** | `m_axi4lite2reg_predictor.bus_in` | 정상(`OKAY`) 응답 트랜잭션에 대한 RAL Mirror 명시적 갱신 |
| **`m_axi4lite_agent.ap`** | `m_scoreboard.axil_fifo.analysis_export` | CSR 버스 응답 상시 검증, `STATE_IN_0~7` Custom IV 추적, `DIGEST_0~7` 수집 및 해시 채점 트리거 |
| **`m_axi4lite_agent.ap`** | `m_csr_coverage.analysis_export` | CSR 접근 권한, Busy 충돌 및 에러 응답 커버리지 샘플링 |
| **`m_axi4lite_agent.ap`** | `m_overall_coverage.axil_fifo.analysis_export` | `CTRL.SOFT_RESET` 인가 및 코어 상태 동기화 샘플링 |
| **`m_axis_agent.ap`** | `m_scoreboard.axis_fifo.analysis_export` | `tkeep` 기반 유효 메시지 바이트 추출 및 비정상 중단 패킷 플러시 |
| **`m_axis_agent.ap`** | `m_overall_coverage.axis_fifo.analysis_export` | 입력 페이로드 길이, `All-0x80` 경계 및 블록/정렬 교차 커버리지 샘플링 |
| **`m_core_agent.monitor.ap`** | `m_scoreboard.core_fifo.analysis_export` | 코어 연산 중 리셋 중단 시 잔류 입력 버퍼 폐기 및 연산 Latency 로깅 |
| **`m_core_agent.monitor.ap`** | `m_overall_coverage.core_fifo.analysis_export` | Soft Reset 인가 시점의 코어 연산 진행 여부(Busy vs. Idle) 상태 추적 |

* **RAL Sequencer 연결:** `m_cfg.csr_rb.default_map`은 `set_sequencer()`를 통해 `m_axi4lite_agent.m_sequencer` 및 `m_reg2axi4lite` 어댑터와 연결되어, RAL API(`read`/`write`) 호출이 AXI4-Lite 버스 트랜잭션으로 변환·구동됩니다.
* **RAL 핸들 공유:** `m_cfg.csr_rb` 객체 핸들은 `m_scoreboard`, `m_csr_coverage`, `m_overall_coverage`에 공유되어, 필드 접근 권한 및 미러 값 조회에 사용됩니다.

# 3. Verification Components (VIPs & Utilities)

## 3.1 AXI4-Lite Master VIP (`axi4lite_agent`)
`axi4lite_agent`는 AMBA AXI4-Lite 프로토콜 사양을 준수하는 Active Master VIP입니다. UVM 클래스 계층과 물리 핀 제어 계층(BFM)을 분리한 Dual-Top 구조로 동작하며, RAL Adapter를 통한 추상화 레지스터 접근과 Raw Sequence/Item을 통한 프로토콜 레벨 직접 구동을 동시에 지원합니다. (VIP 개발 문서 `axil_vip_architecture.md` 및 `axil_user_guide.md` 참조)

![AXI4-Lite Master VIP Architecture](figures/AXIL_Arch_3_1.png)


### 3.1.1 Static Width Allocation & 32-bit Dynamic Masking
VIP 내부 데이터 구조는 최대 지원 폭인 64-bit를 기준으로 정적 할당되어 있으며 런타임 설정(32-bit / 64-bit)에 따라 마스킹됩니다.
* **Sequence Item 및 인터페이스 고정 할당:** `axi4lite_seq_item`의 `addr`, `wdata`, `rdata` 변수와 `axi4lite_if`의 물리적 데이터 신호 폭은 64-bit(`logic [63:0]`)로 고정되어 있습니다.
* **HDL 물리 핀 매핑 (`hdl_top`):** SHA-256 DUT의 포트 규격에 맞춰 주소는 하위 8-bit(`awaddr[7:0]`, `araddr[7:0]`), 데이터는 하위 32-bit(`wdata[31:0]`, `rdata[31:0]`), 스트로브는 하위 4-bit(`wstrb[3:0]`)만 연결합니다.
* **Monitor 논리 마스킹 (`m_monitor`):** `DATA_WIDTH = 32` 설정 시, `axi4lite_monitor`의 `notify_transaction` 함수에서 수집된 `wdata` 및 `rdata`의 상위 32비트를 `64'h0000_0000_FFFF_FFFF`로 마스킹한 후 Analysis Port(`ap`)로 Broadcast합니다.

### 3.1.2 BFM Operation (`AXI4LITE_drv_bfm` & `AXI4LITE_mon_bfm`)
물리 계층의 채널 구동 및 샘플링은 `AXI4LITE_drv_bfm`과 `AXI4LITE_mon_bfm`에서 병렬 태스크로 처리됩니다.

* **병렬 채널 구동 및 샘플링:** `AXI4LITE_drv_bfm`은 Write 트랜잭션 시 `fork-join` 블록을 통해 주소(AW) 채널과 데이터(W) 채널을 독립적으로 병렬 구동합니다. `AXI4LITE_mon_bfm` 역시 `monitor_write`와 `monitor_read` 태스크를 `fork-join`으로 버스 트래픽을 상시 샘플링합니다.
* **핸드셰이크 지연 구동:** 트랜잭션 아이템에 설정된 채널별 지연 변수(`aw_delay`, `w_delay`, `b_delay`, `ar_delay`, `r_delay`)만큼 클록 사이클을 대기한 후 Valid 또는 Ready 신호를 인가합니다.
* **Ready Timeout 감시:** `ignore_ready_timeout == 0` 상태에서 슬레이브의 Ready 응답이 100 사이클 이내에 도달하지 않으면 Driver BFM에서 Timeout 에러(`UVM_ERROR`)를 발생시킵니다.
* **트랜잭션 단위 동적 SVA 마스킹:** `AXI4LITE_drv_bfm`은 `drive_write()` 및 `drive_read()` 수행 시 트랜잭션 아이템의 에러 주입 flag(`req.force_unaligned_addr`, `req.ignore_ready_timeout`)가 활성화된 경우, 해당 트랜잭션 구동 구간 동안에만 `axi4lite_if`의 SVA 마스킹 변수(`disable_alignment_sva`, `disable_timeout_sva`)를 동적으로 활성화하고 핸드셰이크 완료 직후 기본 설정값(`m_cfg.disable_*_sva`)으로 자동 복원합니다.

### 3.1.3 `axi4lite_seq_item` Data Structure
시퀀서, 드라이버, 모니터 간에 전달되는 `axi4lite_seq_item`의 주요 필드 정의는 다음과 같습니다.

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `dir` | `dir_e`<br>(`READ`, `WRITE`) | 트랜잭션 접근 방향 지정 |
| `addr` | `logic [63:0]` | 접근 대상 물리 주소 (32-bit 모드에서는 하위 비트 사용, RAL 역참조 및 정렬 검사 대상) |
| `wdata` / `rdata` | `logic [63:0]` | 쓰기 및 읽기 데이터 (32-bit 모드 시 모니터에서 상위 32비트 `0` 마스킹) |
| `wstrb` | `logic [7:0]` | Write 바이트 스트로브 (32-bit 모드에서는 하위 4비트 `wstrb[3:0]` 유효) |
| `prot` | `logic [2:0]` | AXI 보호 속성(`AxPROT`, `prot[1]`을 통해 Secure `0` / Non-secure `1` 구분) |
| `resp` | `logic [1:0]` | 슬레이브 응답 코드(`OKAY=2'b00`, `SLVERR=2'b10`, `DECERR=2'b11`) |
| `aw_delay`, `w_delay`,<br>`b_delay`, `ar_delay`,<br>`r_delay` | `int` | Write(AW/W/B) 및 Read(AR/R) 각 채널의 핸드셰이크 인가 지연 사이클(`0~20` cycles) |
| `force_unaligned_addr`,<br>`force_invalid_wstrb`,<br>`ignore_ready_timeout` | `bit` | 프로토콜 에러 주입 제어 flag (기본값 `0`, 활성화 시 `AXI4LITE_drv_bfm`에서 해당 트랜잭션 구간 동안 관련 SVA 자동 마스킹) |

### 3.1.4 Agent Configuration & Sequence Library
`axi4lite_agent_config`의 설정 파라미터와 `axi4lite_agent_pkg`에서 제공하는 시퀀스 구성은 다음과 같습니다. (각 테스트 클래스별 Parameter Override 및 상위 검증 시나리오 매핑은 6.2절 참조)

**1. Agent Configuration Parameters (`axi4lite_agent_config`)**

| Parameter Name | Type (Default) | Description |
| :--- | :--- | :--- |
| `active` | `uvm_active_passive_enum`<br>(`UVM_ACTIVE`) | Master Driver 및 Sequencer 생성 여부 제어 (`UVM_ACTIVE` / `UVM_PASSIVE`) |
| `ADDR_WIDTH` /<br>`DATA_WIDTH` | `int`<br>(`32` / `32`) | 논리 주소 및 데이터 버스 폭 설정 (`DATA_WIDTH`는 32 또는 64만 지원하며 이외 값 설정 시 `UVM_FATAL` 발생) |
| `has_functional_coverage` | `bit` (`1`) | `axi4lite_coverage` 생성 및 프로토콜 커버리지 수집 활성화 |
| `enable_random_delay` | `bit` (`0`) | RAL Adapter 변환 시 채널별 핸드셰이크 딜레이 제어 (`0`: 0-cycle 고정, `1`: 0~20 사이클 무작위 지연) |
| `disable_alignment_sva`,<br>`disable_timeout_sva` | `bit`<br>(`0` / `0`) | 상시 감시(`0`)를 기본으로 운용하며, 에러 주입 아이템 구동 시에는 `AXI4LITE_drv_bfm`이 해당 트랜잭션 구간 동안만 `axi4lite_if` 내장 SVA를 자동 마스킹 후 복원함 |

**2. AXI4-Lite Stimulus & Sequence API**

| Stimulus Type | Sequence / Method | Primary Control Knobs / API |
| :--- | :--- | :--- |
| **RAL Adaptation** | `reg2axi4lite_adapter` | `read()`, `write()`, Built-in RAL Sequences |
| **Direct Item** | `axi4lite_seq_item` | `addr`, `dir`, `wdata`, `wstrb`, `prot`, `force_*` |
| **Base Sequence** | `axi4lite_write_seq` | `addr`, `wdata`, `wstrb`, `prot` |
| **Coverage / Error Seq** | `axi4lite_protocol_cov_seq`<br>`axi4lite_err_inject_seq` | `aw/w_delay`, `wstrb`, `force_unaligned_addr`,<br>`force_invalid_wstrb` |

**Protocol-Level Behavior**

* **RAL Adaptation (`reg2axi4lite_adapter`):** `uvm_reg_bus_op`을 단일 Beat AXI4-Lite R/W 트랜잭션(`prot = 3'b000`)으로 변환하여 구동합니다.
* **Direct Item (`axi4lite_seq_item`):** 시퀀서를 통해 axi4lite_seq_item의 변수들을 직접 지정하여 단일 트랜잭션을 인가합니다.
* **Base Sequence (`axi4lite_write_seq`):** RAL 경로를 거치지 않고 지정된 물리 주소(`addr`)와 데이터(`wdata`), 스트로브(`wstrb`), 보호 속성(`prot`)으로 즉시 Write 트랜잭션을 구동 후, `resp`를 수집합니다.
* **Coverage / Error Seq (`axi4lite_protocol_cov_seq`, `axi4lite_err_inject_seq`):** AW/W 채널 딜레이 교차 및 부분 스트로브 조합을 생성하는 커버리지 시퀀스와 비정렬 주소(`force_unaligned_addr`) 및 잘못된 스트로브(`force_invalid_wstrb`)를 무작위 인가하는 에러 주입 시퀀스를 구동합니다.


## 3.2 AXI4-Stream Master VIP (`axis_agent`)

`axis_agent`는 런타임 설정(`is_master`)에 따라 Master/Slave을 전환할 수 있는 VIP입니다. 본 SHA-256 검증 환경에서는 DUT의 수신 인터페이스(`s_axis_*`)로 메시지 페이로드를 전송하기 위해 Active Master 모드(`is_active = UVM_ACTIVE`, `is_master = 1`)로 고정하여 운용합니다. (VIP 개발 문서 `axis_vip_architecture.md` 및 `axis_user_guide.md` 참조)

![Top-Level AXI4-STREAM Architecture Diagram](figures/AXIS_Arch_3_2.png)

### 3.2.1 Over-Provisioning Interface & 32-bit Logical Masking
파라미터 변경이나 인터페이스 코드 수정 없이 다양한 데이터 폭에 대응하기 위해, 물리 계층은 최대 폭으로 고정하고 트랜잭션 생성 단계에서 마스킹하여 사용합니다.

* **1024-bit Over-Provisioning (`axis_if`):** 인터페이스의 물리 신호는 `TDATA` 1024-bit, `TKEEP`/`TSTRB` 128-bit, `TUSER` 1024-bit, `TID`/`TDEST` 32-bit로 할당되어 있으며, 내부적으로 구동 및 Clocking Block(`dr_m_cb`, `dr_s_cb`, `mon_cb`)을 포함합니다.
* **32-bit Dynamic Masking (`active_data_width = 32`):** `axis_seq_item`을 Randomize할 때, `post_randomize()` 함수가 호출되어 `active_data_width`(32-bit)를 초과하는 상위 992비트 데이터와 상위 124비트 `tkeep`/`tstrb`를 자동으로 `0`으로 마스킹합니다.
* **HDL 물리 핀 매핑 (`hdl_top`):** SHA-256 DUT에는 `tdata[31:0]`, `tkeep[3:0]`, `tlast`, `tvalid`, `tready`만 연결하며, DUT에서 사용하지 않는 라우팅 및 사이드밴드 신호(`TSTRB`, `TUSER`, `TID`, `TDEST`)는 연결하지 않습니다.

### 3.2.2 BFM Packet Driving & Reassembly Flow (`AXIS_drv_bfm` & `AXIS_mon_bfm`)
AXI4-Stream의 스트리밍 특성을 반영하여 시퀀스 아이템은 패킷(Packet) 단위로 처리되며, BFM(Bus function Model)에서 Beat 단위 분해 및 재조립을 수행합니다.

* **Master Driver BFM 구동 및 타임아웃 감시 (`AXIS_drv_bfm`):**
  * 상위 드라이버로부터 전달받은 패킷은 `push_transaction()`에서 리셋 해제를 확인 후, `tid` 기준 연관 배열(`active_pkt_q`)에 등록되며, 설정된 중재 방식(`arb_mode`)과 `valid_delay_q` 지연 값에 따라 각 Beat를 순차 인가합니다.
  * 구동 중 리셋이 감지되면 즉시 출력 신호와 내부 패킷 큐를 초기화합니다. 또한 `s_axis_tready === 1'bx`가 감지되거나 단일 Beat 대기(`drive_bus`) 및 패킷 완료 대기(`wait_pkt_done`)가 `timeout_cycles`(기본 1000 사이클)를 초과하면 즉시 `UVM_ERROR`를 발생시키고 해당 패킷 큐를 비워 시뮬레이션 교착(Hang)을 방지합니다.
* **Monitor BFM 패킷 재조립 및 자동 플러시 (`AXIS_mon_bfm`):**
  * **패킷 재조립(Reassembly):** 핸드셰이크 발생 시 Beat 데이터를 샘플링하여 누적하고, `tvalid` 대기 사이클(`ipg_cnt`)과 `tready` 대기 사이클(`r_delay_cnt`)을 기록합니다. `tlast == 1`인 Beat가 샘플링되면 `status = OK`로 설정하여 상위 `axis_monitor.ap`로 전달합니다.
  * **리셋 및 예외 자동 플러시 (`monitor_reset` & `flush`):** AXIS VIP에 리셋이 전달되면 `monitor_reset()`이 이를 즉시 감지하여 `flush()`를 자동 실행합니다. 이후 미완성 패킷이 `status = INCOMPLETE`로 태깅되어 브로드캐스트되며, 이를 수신한 `sha256_scoreboard`는 내부 데이터 큐(`msg_queue`)를 즉시 비워 후속 트랜잭션의 채점 오염을 방지합니다.

### 3.2.3 `axis_seq_item` Data Structure
패킷 단위로 정의된 `axis_seq_item`의 주요 동적 큐 및 제어 변수는 다음과 같습니다.

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `tdata_q[$]` | `logic [1023:0]` | 패킷 내 각 Beat의 페이로드 데이터 동적 큐 (기본 크기 제약 `1~64` Beats, 32-bit 모드 시 하위 `[31:0]` 유효) |
| `tkeep_q[$]` /<br>`tstrb_q[$]` | `logic [127:0]` | 각 Beat의 유효 바이트(Qualifier) 및 스트로브 큐 (32-bit 모드 시 하위 `[3:0]` 유효) |
| `tuser_q[$]` /<br>`tid` / `tdest` | `logic [1023:0]` /<br>`logic [31:0]` | 사이드밴드 및 라우팅 식별자 (DUT 미사용 핀) |
| `valid_delay_q[$]` | `int` | 각 Beat의 `tvalid` 인가 전 대기 사이클 (기본 제약 `0~10` cycles) |
| `ready_delay_q[$]` | `int` | Monitor BFM이 각 Beat 핸드셰이크 시 샘플링한 슬레이브 `tready` 대기(Back-pressure) 사이클 기록 큐 |
| `status` | `status_e`<br>(`OK`, `INCOMPLETE`,<br>`PROTOCOL_ERR`) | 패킷 전송 완료 상태 flag (`TLAST` 정상 완료 시 `OK`, 리셋/예외 플러시 시 `INCOMPLETE`) |
| `drop_tlast`,<br>`force_tkeep_error` | `bit` | 스트림 에러 주입 flag (기본값 `0`, 마지막 Beat `tlast` 누락 및 비정상 `tkeep` 패턴 강제 인가) |

### 3.2.4 Agent Configuration & Sequence Library
`axis_agent_config`의 설정 파라미터와 `axis_agent_pkg`에서 제공하는 마스터 시퀀스 라이브러리는 다음과 같습니다. (상위 테스트별 시퀀스 활용 시나리오는 6.2절 참조)

**1. Agent Configuration Parameters (`axis_agent_config`)**

| Parameter Name | Type (Default) | Description |
| :--- | :--- | :--- |
| `is_active` /<br>`is_master` | `uvm_active_passive_enum` / `bit`<br>(`UVM_ACTIVE` / `1`) | Active Master 모드(`axis_m_driver` 및 `AXIS_drv_bfm`) 활성화 |
| `active_data_width` | `int` (`32`) | 1024-bit 물리 인터페이스 중 유효하게 사용할 데이터 비트 폭 설정 (하위 32-bit 및 `tkeep[3:0]` 마스킹) |
| `arb_mode` | `axis_arb_mode_e`<br>(`ARB_RR`) | 다중 `tid` 패킷 큐(`active_pkt_q`) 구동 시의 중재 방식 설정 (`ARB_RR` / `ARB_RANDOM`) |
| `timeout_cycles` | `int` (`1000`) | `tvalid` 인가 후 슬레이브의 `tready` 응답 최대 대기 허용 사이클 설정 (`axis_if`의 `MAXWAITS = 2048` 이내) |
| `has_functional_coverage` | `bit` (`1`) | `axis_coverage` 생성 및 스트림 프로토콜 커버리지 수집 활성화 |

**2. AXI4-Stream Master Sequence Library**

| Sequence / Item | Control Knobs |
| :--- | :--- |
| `axis_seq_item` (Direct) | `tdata_q`, `tkeep_q`, `valid_delay_q` |
| `axis_m_single_seq` | `pkt_len` |
| `axis_m_basic_seq` | `pkt_len` (`2~64`) |
| `axis_m_stream_seq` | `payload_data[]` (`byte`) |
| `axis_m_short_delay_seq`,<br>`axis_m_slow_seq` | `num_trans`, `pkt_len_min/max`, `delay_min/max`,<br>`zero_delay_prefix_beats` |
| `axis_m_err_inject_seq` | `pkt_len`, `do_tlast_drop`, `do_tkeep_err`,<br>`zero_prefix_delay`, `final_beat_delay` |

**Protocol-Level Behavior (시퀀스별 스트림 구동 동작):**

* **`axis_seq_item` (Direct):** 큐 기반의 단일 패킷 아이템을 직접 구성하여 Sequencer(`axis_sqr`)로 전송합니다.
* **`axis_m_single_seq`:** `valid_delay = 0` 조건으로 지정된 Beat 수(`pkt_len`)의 단일 패킷을 지연 없이 고속 전송합니다.
* **`axis_m_basic_seq`:** 다중 Beat(Burst) 패킷을 기본 딜레이 제약(`0~10` 사이클) 하에서 무작위 생성하여 전송합니다.
* **`axis_m_stream_seq`:** 임의 바이트 길이를 갖는 `payload_data` 동적 배열을 입력받아 32-bit(4바이트) Beat 단위로 자동 분할하고, 마지막 Beat의 잔여 바이트 수(1~4B)에 맞춰 유효한 `tkeep`(`4'b0001`~`4'b1111`)과 `tlast=1`을 자동 생성하여 전송합니다.
* **`axis_m_short_delay_seq`, `axis_m_slow_seq`:** 다중 패킷(`num_trans`)의 Beat 간 `tvalid` 인가 지연(`valid_delay_q`)을 단기(`1~5` 사이클) 또는 장기(`10~100` 사이클) 범위로 강제하며, `zero_delay_prefix_beats` 설정을 통해 무지연 버스트 전송 후 지연 인가를 지원합니다.
* **`axis_m_err_inject_seq`:** 패킷의 마지막 Beat에서 `tlast` 신호를 누락(`drop_tlast = 1`)시키거나 비정상 `tkeep` 패턴(비연속 Sparse 또는 패킷 중간 Partial 스트로브를 `active_byte_mask` 내에서 무작위 생성)을 강제 주입하며, 다중 Beat 패킷 구동 시 마지막 Beat 제어(`zero_prefix_delay`, `final_beat_delay`)를 지원합니다. 단, VIP 기본 제약으로 제외된 `tkeep == 4'b0000`은 지원하지 않습니다.

## 3.3 SHA-256 Core Passive Agent (`core_agent`)
`core_agent`는 Wrapper 내부에 인스턴스화된 연산 코어(`DUT.u_core`)의 입출력 데이터와 컨트롤러 상태 신호를 관찰하는 White-box Passive Agent(`is_active = UVM_PASSIVE`)입니다. 외부 핀을 구동하지 않으므로 Sequencer와 Driver를 포함하지 않으며, `core_monitor`와 `core_coverage`로만 구성됩니다. (코어 하드웨어 아키텍처 및 67사이클 FSM 사양은 `Micro_Architecture_Specification.md` 5장 참조)

![Top-Level Core Agent Architecture Diagram](figures/CORE_Arch_3_3.png)

### 3.3.1 Internal Signal Probing & Reset Domain Mapping (`core_if`)

`hdl_top`에서는 계층적 참조(Hierarchical Reference)를 통해 3개 영역의 내부 신호를 `core_if`에 `assign`으로 연결합니다. 모든 신호는 `core_if` 내부의 Clocking Block(`mon_cb`)을 통해 클록 상승 엣지 직전(`default input #1step`)의 안정화된 값으로 샘플링됩니다.

| Source Hierarchy | Probed Signals | Width |
| :--- | :--- | :--- |
| **`DUT.u_core`**<br>(Core Native I/O) | `start_i`, `ready_o`, `busy_o`, `done_o`<br>`block_i`<br>`state_in_i`, `state_out_o` | 1, 1, 1, 1<br>512<br>256, 256 |
| **`DUT.u_core.u_controller`**<br>(Controller FSM) | `init_o`, `load_block_o`,<br>`round_en_o`, `update_o`, `round_idx_o` | 1, 1,<br>1, 1, 6 |
| **`DUT`**<br>(Wrapper Context) | `first_block` | 1 |

**Probed Signal Verification Purpose & Reset Domain Mapping:**

* **`DUT.u_core` (Core Native I/O):** 코어 연산 시작(`start_i && ready_o`) 및 완료(`done_o`) 시점을 감지하고, 패딩 및 Big-Endian 변환이 완료된 512-bit 입력 블록과 256-bit 입출력 해시값을 추출합니다.
* **`DUT.u_core.u_controller` (Controller FSM):** `CORE_mon_bfm`은 `load_block_o == 1`(`STATE_INIT`) 시점에 코어로 적재되는 `block_i`와 `state_in_i`를 샘플링하고, `round_idx_o`를 추적하여 연산 중 리셋 발생 시 중단된 라운드 인덱스(`0~63`)를 트랜잭션에 기록합니다. 나머지 파이프라인 제어 신호(`init_o`, `round_en_o`, `update_o`)는 파형 관측 및 `sha256_core_sva` 검증에 활용됩니다.
* **`DUT` (Wrapper Context):** 코어 자체는 체이닝 여부를 인지하지 못하므로, Wrapper의 `first_block` flag를 함께 관측하여 현재 블록이 단일/첫 블록(`1`)인지 체이닝 블록(`0`)인지 판별합니다.
* **Reset Domain 분리 연결 (`rst_n_i` vs `DUT.core_rst_n`):** `core_if`는 비동기 리셋(`rst_n_i`)을 입력받아 리셋 SVA(`p_rst_basic`, `p_rst_active`, `a_rst_async`)를 감시하며, `CORE_mon_bfm` 및 코어 SVA(`bind_core_sva`)의 리셋 포트에는 하드웨어 리셋, `SOFT_RESET`, `TKEEP` 위반이 결합된 `DUT.core_rst_n`을 연결하여 연산 중 예외 중단을 감지합니다.

### 3.3.2 Split-Phase Transaction Sampling (`core_monitor_bfm` & `core_seq_item`)

`CORE_mon_bfm`은 내부 큐(`active_q[$]`)를 공유하는 두 개의 병렬 태스크(`monitor_write`, `monitor_read`)를 구동합니다.

1. **Input Phase Capture (`monitor_write`):**
   * **Trigger & Capture:** Clocking Block(`@(vif.mon_cb)`) 기준 리셋이 해제된 상태에서 `start_i && ready_o` 핸드셰이크가 감지되면 `core_seq_item` 객체를 생성합니다.
   * **Queue Hand-off:** Wrapper의 체이닝 flag(`first_block`)를 샘플링하여 `active_q[$]`에 Push합니다.
2. **Output & Exception Capture (`monitor_read`):**
   * `active_q[$]`에서 Pop하여 `fork-join_any` 블록을 통해 정상 완료 대기 스레드와 리셋 감지 스레드를 동시에 실행합니다.
   * **정상 완료 경로 (`wait_done`, `is_aborted == 0`):** 코어가 입력 블록을 내부 레지스터로 실제 적재하는 `STATE_INIT` 사이클에 `block_i`와 `state_in_i`를 샘플링하고, `done_o == 1`이 될 때까지 `round_idx_o`를 추적합니다. 완료 시점에 누적된 `latency`와 최종 해시 출력(`state_out_o`)을 아이템에 기록합니다.
   * **리셋 중단 경로 (`wait_async_reset`, `is_aborted == 1`):** 연산 도중 코어 리셋이 감지되면 즉시 스레드를 종료하고, 중단 시점의 경과 사이클(`aborted_cycle`)과 라운드 번호(`aborted_round`)를 기록합니다.
   * **Broadcast & Post-Reset Flush:** 두 스레드 중 하나가 완료되면 `disable fork`로 잔여 스레드를 정리하고 `core_monitor.ap`로 아이템을 Broadcast합니다. 만약 리셋 중단(`is_aborted == 1`)이 발생한 경우에는 리셋이 해제(`rst_n_i == 1`)될 때까지 대기한 뒤 잔여 `active_q[$]`를 모두 비워(`delete()`) 모니터 상태를 초기화합니다.

### 3.3.3 `core_seq_item` Data Structure

`core_monitor.ap`를 통해 Broadcast되는 `core_seq_item`의 필드 정의는 다음과 같습니다.

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `block_i` | `logic [511:0]` | 코어로 인가된 512-bit 메시지 블록 (`core_coverage` 데이터 패턴 샘플링 대상) |
| `state_in_i` | `logic [255:0]` | 코어 입력 적재(`load_block_o == 1`) 시점의 256-bit 초기 해시 상태값(IV 또는 이전 블록 DIGEST) 캡처 |
| `state_out_o` | `logic [255:0]` | 정상 완료(`done_o == 1`) 시점의 256-bit 해시 결과값 캡처 |
| `first_block` | `logic` | Wrapper에서 전달된 첫 블록 여부 flag (`1`: 단일/첫 블록, `0`: 연속 체이닝 블록) |
| `latency` | `int` | `start_i` 인가 후 `done_o` 출력까지 소요된 클록 사이클 수 |
| `is_aborted` | `bit` | 연산 중 리셋(비동기, Soft Reset 또는 `TKEEP` 에러)에 의한 중단 여부 flag (`0`: 정상 완료, `1`: 중단) |
| `aborted_cycle` | `int` | 리셋 중단 시 `start_i` 이후 경과한 클록 사이클 수(`0~66`) |
| `aborted_round` | `logic [5:0]` | 리셋 중단 시점의 코어 라운드 인덱스(`0~63`) |

## 3.4 Auxiliary Utilities (`intr_util` & `rst_util`)

완료 인터럽트(`irq_o`) 감지와 비동기 하드웨어 리셋(`rst_n_i`) 구동 및 클록 사이클 동기화는 프로토콜 트랜잭션에 해당하지 않으므로, 별도의 UVM Agent를 구성하는 대신 `uvm_object` 기반의 유틸리티 클래스(`intr_util`, `rst_util`)와 전용 BFM(`intr_bfm`, `rst_bfm`)을 1:1로 매핑하여 제어합니다. `sha256_test_base::build_phase`에서 각 유틸리티 객체를 생성하고 `set_bfm()` 함수를 호출하면, 유틸리티의 `m_bfm` 핸들과 BFM 내부의 `proxy` 핸들이 양방향 바인딩됩니다.

![Utility diagram](figures/UTIL_Arch_3_4.png)

검증 환경에서 사용하는 두 유틸리티 클래스의 제공 API 요약은 다음과 같습니다.

| Utility Class | Method Name | Type | Description |
| --- | --- | --- | --- |
| **`intr_util`** | `set_bfm(virtual intr_bfm bfm)` | Function | `m_bfm` 및 `bfm.proxy` 양방향 핸들 바인딩 |
| **`intr_util`** | `wait_for_interrupt()` | Task | `irq_o`가 High(`1`)가 될 때까지 호출 시퀀스를 블로킹 |
| **`intr_util`** | `wait_for_clear()` | Task | `INTCLEAR` 쓰기 등을 통해 `irq_o`가 Low(`0`)로 해제될 때까지 블로킹 |
| **`intr_util`** | `get_irq_level()` | Function | 블로킹 없이 현재 저장된 인터럽트 상태(`intr_val`) 반환 |
| **`rst_util`** | `set_bfm(virtual rst_bfm bfm)` | Function | `m_bfm` 및 `bfm.proxy` 양방향 핸들 바인딩 |
| **`rst_util`** | `assert_reset(int cycles = 20)` | Task | `m_bfm.drive_reset(cycles)`를 호출하여 지정된 클록 사이클 동안 하드웨어 리셋(`rst_n_i = 0`)을 인가하고 리셋 해제 후 첫 클록 상승 엣지까지 동기화 대기 |
| **`rst_util`** | `wait_cycles(int cycles = 1)` | Task | `m_bfm.wait_cycles(cycles)`를 호출하여 지정된 시스템 클록 사이클만큼 동기식 대기 수행 |
| **`rst_util`** | `wait_for_reset_done()` | Task | `m_bfm.wait_for_reset_done()`을 호출하여 리셋 해제(`rst_n_o === 1'b1`) 및 첫 클록 상승 엣지까지 시퀀스 시작을 동기화 |
| **`rst_util`** | `wait_for_reset()` | Task | 하드웨어 리셋 인가 시 `RST_bfm`이 발생시키는 `@reset_asserted` 이벤트 대기 |

### 3.4.1 Interrupt Synchronization (`intr_util` & `intr_bfm`)

`intr_util`과 `INTR_bfm`은 하드웨어 인터럽트 핀(`irq_o`)의 레벨 변화를 감지하여 Virtual Sequence의 실행 타이밍을 동기화합니다.

* **클록 동기식 엣지 검출 (`INTR_bfm`):** 리셋이 해제(`rst_n_i == 1`)된 상태에서 매 클록 상승 엣지마다 현재 `irq_o` 핀의 값과 `proxy.get_irq_level()`(이전 상태값 `intr_val`)을 비교합니다.
* **Rising Edge (`0 -> 1`):** `proxy.notify_interrupt()`를 호출하여 `intr_val = 1`로 갱신하고 `intr_asserted` 이벤트를 발생시킵니다.
* **Falling Edge (`1 -> 0`):** `proxy.notify_interrupt_cleared()`를 호출하여 `intr_val = 0`으로 갱신하고 `intr_deasserted` 이벤트를 발생시킵니다.
* **Event Race Condition 방지 (`intr_util`):** 시퀀스가 대기 태스크를 호출하기 이전에 이미 인터럽트가 발생했을 경우 Deadlock에 빠지는 것을 방지하기 위해, 이벤트 대기 전 상태 flag(`intr_val`)를 먼저 확인합니다. `wait_for_interrupt()`는 `intr_val == 0`일 때만 `@intr_asserted`를 대기하며, 이미 `1`인 경우 즉시 반환됩니다. `wait_for_clear()` 역시 `intr_val == 1`일 때만 `@intr_deasserted`를 대기합니다.
* **내장 SVA (`p_rst_irq`):** `INTR_bfm` 내부에는 시스템 리셋 인가 시 인터럽트 출력이 즉시 비활성화되는지 SVA를 통해 검증합니다.

### 3.4.2 Dynamic Reset Control & Clock Synchronization (`rst_util` & `rst_bfm`)

`rst_util`과 `RST_bfm`은 시뮬레이션 초기 리셋, 테스트 시나리오 도중의 동적 하드웨어 리셋 인가, 그리고 클록 사이클 기반 지연 동기화를 전담합니다.

* **Power-on Reset 구동 및 초기 동기화 (`wait_for_reset_done`):** 시뮬레이션 시작 시 `RST_bfm`의 `initial` 블록이 `rst_n_o = 1'b0`을 인가하고 20 클록 사이클 대기 후 `1'b1`로 해제합니다. 모든 Virtual Sequence는 `sha256_base_vseq::body()`에서 `wait_for_reset_done()`을 호출하여 초기 리셋이 완전히 해제된 직후의 클록 상승 엣지부터 트랜잭션을 구동합니다.
* **BFM 태스크 캡슐화 및 Output Skew 적용 (`drive_reset` & `notify_reset`):** Virtual Sequence가 `assert_reset(cycles)`를 호출하면 `RST_bfm` 내부의 `drive_reset(cycles)` 태스크가 실행됩니다. `RST_bfm`은 클록 엣지에서의 신호 경합(Race condition)을 방지하기 위해 **`#1ns`의 Output Skew** 지연 후 `rst_n_o = 1'b0`을 구동함과 동시에 `proxy.notify_reset()`을 호출하여 Scoreboard(`wait_for_reset()`)에 리셋 진입을 통지합니다. 이후 지정된 `cycles` 클록 동안 대기한 뒤 동일하게 `#1ns` 지연 후 `rst_n_o = 1'b1`로 복구하고, 다음 클록 상승 엣지까지 대기한 뒤 시퀀스 제어권을 반환합니다.
* **Time-Agnostic 클록 사이클 대기 (`wait_cycles`):** HVL 시퀀스나 테스트 클래스에서 물리적 클록 핀(`clk_i`)을 직접 폴링하거나 절대 시간(`#ns`, `#us`)을 하드코딩하지 않도록 `RST_bfm`의 `wait_cycles(cycles)` 태스크를 통해 클록 주기에 독립적인 사이클 지연 API를 제공합니다.


# 4. Register Model (RAL) & Scoreboard Checking Mechanism

## 4.1 PeakRDL Automation & Bus Adaptation

### 4.1.1 PeakRDL-Based RAL Code Generation (`sha256_csr.rdl` -> `sha256_reg_pkg.sv`)
UVM 환경에서 레지스터를 검증하려면 DUT의 모든 CSR을 대응하는 SystemVerilog 클래스(`uvm_reg`, `uvm_reg_block`)로 모델링해야 합니다. 본 프로젝트는 오픈소스 레지스터 자동화 툴인 **PeakRDL**을 사용했습니다.

* **SystemRDL 스펙 정의 (`sha256_csr.rdl`):** 하드웨어 설계 사양서(MAS 4.2절)에 정의된 메모리 맵을 표준 레지스터 기술 언어인 SystemRDL 포맷으로 작성합니다. 각 레지스터의 주소 오프셋, 소프트웨어/하드웨어 접근 권한(`sw`, `hw`), 단일 클록 펄스 속성(`singlepulse`), 리셋 초기값(표준 IV 상수 포함) 등 CSR을 정의합니다.
* **UVM RAL 패키지 자동 생성 (`sha256_reg_pkg.sv`):** PeakRDL 컴파일러가 `.rdl` 파일을 파싱하여 UVM 표준 규격의 `sha256_csr` 블록 클래스를 생성합니다. 테스트 시퀀스는 이 객체를 통해 `csr_rb.CTRL.write()`와 같이 레지스터 이름으로 읽기/쓰기 동작을 수행합니다.

### 4.1.2 RAL Bus Adapter (`reg2axi4lite_adapter.svh`)
RAL 모델이 생성한 추상화된 레지스터 읽기/쓰기 명령(`uvm_reg_bus_op`)을 실제 물리 버스에 인가하려면 AXI4-Lite VIP의 트랜잭션 아이템(`axi4lite_seq_item`)으로 변환해 주는 어댑터가 필요합니다. `reg2axi4lite_adapter`는 바이트 스트로브를 지원(`supports_byte_enable = 1`)하며 다음 두 함수를 통해 양방향 변환을 수행합니다.

* **`reg2bus()` (RAL 명령 -> AXI4-Lite 트랜잭션 변환):**
  * RAL의 접근 방향, 주소, 쓰기 데이터, 바이트 스트로브를 `axi4lite_seq_item`(`dir`, `addr`, `wdata`, `wstrb`)에 매핑합니다. 표준 RAL 접근은 정상 보안 권한을 전제하므로 `prot = 3'b000`(Secure)으로 고정합니다.
  * `axi4lite_agent_config.enable_random_delay` 설정값에 따라, `0`이면 모든 채널(`aw`, `w`, `b`, `ar`, `r`)의 핸드셰이크 딜레이를 0 사이클로 고정하고, `1`이면 아이템 랜덤화를 호출하여 채널별로 0~20 사이클의 무작위 버스 지연을 인가합니다.
* **`bus2reg()` (AXI4-Lite 트랜잭션 -> RAL 결과 변환):**
  * 버스에서 완료된 트랜잭션의 방향, 주소, 그리고 데이터(`READ` 시 `rdata`, `WRITE` 시 `wdata`)를 RAL 구조체(`uvm_reg_bus_op`)로 전달합니다.
  * **버스 에러 상태 번역:** AXI 응답(`resp`)이 정상(`2'b00` 또는 `2'b01`)일 때는 `UVM_IS_OK`를 반환하지만, 하드웨어 방화벽이나 주소 디코드 에러로 인해 `SLVERR`(`2'b10`) 또는 `DECERR`(`2'b11`)가 발생한 경우 `UVM_NOT_OK`로 변환하여 상위 Predictor에 에러 발생 사실을 알립니다.


## 4.2 Explicit Prediction & Cross-Component RAL Sharing

### 4.2.1 Explicit Prediction Loop & Mirror Protection
본 테스트벤치는 드라이버 구동 시점에 미러 값을 자동으로 갱신하는 Implicit Prediction을 비활성화(`set_auto_predict(0)`)하고, 모니터가 관찰한 실제 버스 트랜잭션을 `uvm_reg_predictor`에 통과시켜 미러 값을 갱신하는 **Explicit Prediction** 방식을 사용합니다.

1. **Stimulus Generation (`Virtual Sequence` -> `csr_rb` / `axil_sqr`):** 시퀀스에서 RAL API(`read()` / `write()`, 내장 시퀀스)를 호출하거나 Raw Sequence Item을 시퀀서로 직접 인가합니다.
2. **Forward Adaptation (`csr_rb` -> `reg2axi4lite_adapter::reg2bus`):** RAL 접근인 경우 어댑터가 `uvm_reg_bus_op`을 `axi4lite_seq_item`으로 변환하여 `m_axi4lite_agent.m_sequencer`로 전달합니다.
3. **Physical Bus Drive & Sample (`m_driver` -> `DUT` -> `m_monitor`):** Driver BFM이 DUT의 AXI4-Lite 핀을 구동하고, Monitor BFM이 완료된 트랜잭션과 슬레이브 응답(`OKAY`, `SLVERR`, `DECERR`)을 샘플링하여 `m_monitor.ap`로 Broadcast합니다.
4. **Reverse Adaptation & Mirror Update (`m_monitor.ap` -> `m_axi4lite2reg_predictor` -> `csr_rb`):** Predictor가 수신된 버스 아이템을 `bus2reg()`로 역변환하며, 응답 상태가 정상(`status == UVM_IS_OK`)인 경우에만 `csr_rb`의 미러 값을 갱신합니다.

* **하드웨어 방화벽에 의한 에러 응답 처리:** DUT는 비보안 접근(`PROT`), 비정렬 주소 접근(`AxADDR[1:0] != 2'b00`), 연산 중(`STATUS.BUSY == 1`) 제어/초기 상태 레지스터 변경 시도, RO 레지스터 쓰기 시도 시 내부 레지스터 변경을 차단하고 `SLVERR`를 반환합니다. Explicit Prediction 구조에서는 `SLVERR` 또는 `DECERR` 발생 시 Adapter의 `bus2reg()`가 `UVM_NOT_OK`를 전달하므로 Predictor가 해당 트랜잭션을 폐기합니다. 이를 통해 비정상 쓰기 차단 시 RAL 미러 값 역시 변경되지 않고 실제 하드웨어 레지스터 값과 정합성을 유지합니다.
* **Raw Sequence 구동 시의 미러 동기화:** RAL API를 거치지 않고 `axi4lite_write_seq` 또는 `axi4lite_seq_item`을 시퀀서에 직접 인가하는 시나리오에서는 모니터(`m_axi4lite_agent.ap`)가 캡처한 트랜잭션을 Predictor로 전달하여 RAL 미러 값이 누락 없이 갱신합니다.

### 4.2.2 Cross-Component Handle Sharing & Address Reverse Lookup

`sha256_env::connect_phase`에서 RAL 블록 핸들(`csr_rb`)은 `m_scoreboard`, `m_csr_coverage`, `m_overall_coverage`에 공유되어 검증 로직에 활용됩니다.

* **RAL 역참조 및 동적 필드 속성 조회 (`get_reg_by_offset` & `get_access` / `get_lsb_pos`):**
  * `sha256_scoreboard`는 하위 2비트(`addr[1:0]`)를 마스킹하지 않은 8-bit 물리 주소 오프셋(`{56'd0, item.addr[7:0]}`)으로 `csr_rb.default_map.get_reg_by_offset()`을 호출합니다. 이어서 `target_reg.get_fields(fields)` 및 `fields[0].get_access()`를 통해 해당 레지스터의 접근 권한(`"RO"`, `"WO"`, `"RW"`)을 조회하여 권한 오류를 판정합니다.
  * `sha256_overall_coverage`는 `csr_rb.CTRL.SOFT_RESET.get_lsb_pos()`를 호출하여 `SOFT_RESET` 인가 여부를 추출합니다.
* **미러 상태 조회 및 에러 오염 방어 (`get_mirrored_value()` & `last_valid_busy`):** `sha256_csr_coverage`는 정상 응답(`resp == 2'b00`)을 받은 트랜잭션에서만 `csr_rb.STATUS.BUSY` 필드의 미러 값을 조회하고 `STATUS.DONE` 필드의 전이를 샘플링합니다. `SLVERR` 응답으로 인해 미러 값이 오염되더라도, 직전 정상 Busy 상태를 보존하여 `cr_busy_prot` 커버리지(`<ctrl, write, busy, slverr>`)를 샘플링합니다.


## 4.3 Scoreboard & DPI-C Reference Model Architecture

### 4.3.1 End-to-End Checking Pipeline

`sha256_scoreboard`는 입출력 버스 트랜잭션(`axis_fifo`, `axil_fifo`)을 통해 CSR 예외 응답과 해시 무결성을 검증하는 Black-box 채점 방식을 기본으로 하되, 리셋 및 예외 중단 동기화를 위해 내부 코어 모니터(`core_fifo`)와 리셋 유틸리티(`m_rst_util`)를 보조 참조하는 **Grey-box 구조**로 동작합니다.

| Scoreboard Thread | Connected Source | Primary Pipeline Role |
| :--- | :--- | :--- |
| **`axil_fifo`** (`process_axil_data`) | `m_axi4lite_agent.ap` | RAL 기반 CSR 버스 응답 및 읽기 제로 마스킹 상시 검증, 동작 상태 및 Custom IV 추적, `DIGEST_0~7` 수집 후 해시 비교 트리거 |
| **`axis_fifo`** (`process_axis_data`) | `m_axis_agent.ap` | `tkeep` 기반 유효 메시지 바이트 추출 및 적재 (리셋/예외로 중단된 `INCOMPLETE` 패킷 수신 시 입력 버퍼 Flush) |
| **`core_fifo`** (`process_core_data`) | `m_core_agent.monitor.ap` | 코어 연산 중 리셋 중단 감지 시 내부 Busy 상태 해제 및 잔류 입력 버퍼 폐기, 정상 완료 시 연산 Latency 로깅 |
| **Reset Sync** (`wait_for_reset`) | `m_cfg.m_rst_util` | 동적 하드웨어 리셋(`rst_n_i = 0`) 발생 시 내부 상태, 입력 버퍼 및 초기 해시 벡터(표준 IV 복원) 즉시 초기화 |
| **`compare_hash()`** | `c_sha256_digest()` (DPI-C) | 누적된 입력 메시지 바이트와 초기 해시 벡터(IV)를 C++ 참조 모델로 전달하여 기댓값 산출 및 `DIGEST_0~7` 읽은 값과 대조 |

### 4.3.2 Parallel Processing Loops (`sha256_scoreboard.svh`)

`sha256_scoreboard::run_phase`는 `fork-join`을 통해 4개의 병렬 처리 루프를 상시 구동합니다.

1. **AXI4-Lite 처리 루프 (`process_axil_data`):**
   * **상시 응답 검증 및 상태 추적:** `enable_sb_check`와 무관하게 모든 트랜잭션의 주소를 RAL로 역참조하여, 하드웨어 예외 규칙(보안 속성, 비정렬 주소, 미할당 주소, 필드 권한, Busy 충돌)에 따른 응답 코드(`OKAY`, `SLVERR`, `DECERR`)와 읽기 에러 시 데이터 제로 마스킹을 검증합니다(`check_axil_response`). 또한 정상(`OKAY`) 접근 시 `CTRL`·`STATUS`·`INTCLEAR`·`DIGEST`에 따른 동작 상태(Busy)와 `STATE_IN_0~7`의 Custom IV를 동기화합니다.
   * **해시 채점 트리거:** `enable_sb_check == 1` 상태에서 `DIGEST_0~7` 8개 워드가 모두 읽히면 `compare_hash()`를 호출하여 해시 정합성을 채점하고 입력 버퍼를 초기화합니다.
2. **AXI4-Stream 입력 수집 루프 (`process_axis_data`):**
   * `enable_sb_check == 1`일 때 동작하며, 정상 완료(`status == OK`) 패킷에서 `tkeep`이 유효한 바이트만 Little-Endian 순서로 추출해 버퍼에 적재합니다. 리셋이나 예외로 중단된 패킷(`INCOMPLETE`) 수신 시에는 즉시 버퍼를 비워 후속 연산의 오염을 방지합니다.
3. **Core 연산 중단 동기화 루프 (`process_core_data`):**
   * 상시 동작하며, 코어 연산 중 리셋이나 프로토콜 에러로 인한 중단(`is_aborted == 1`)이 감지되면 내부 Busy 상태를 해제하고 미완성 입력 버퍼를 폐기합니다. 정상 완료 시에는 연산 소요 사이클(`latency`)을 로깅합니다.
4. **하드웨어 리셋 동기화 루프 (`wait_for_reset`):**
   * `m_rst_util.wait_for_reset()`을 통해 동적 하드웨어 리셋 이벤트를 상시 대기하며, 리셋 발생 즉시 내부 Busy 상태와 입력 버퍼를 비우고 초기 해시 벡터를 표준 IV로 복원합니다.

### 4.3.3 DPI-C Reference Model Interface (`sha256_ref_model.cpp`)

`compare_hash()`에서 호출되는 `c_sha256_digest` 함수는 Wrapper의 Padding 변환과 Core의 64라운드 압축 연산을 통합 모델링한 C++ Golden Reference입니다.

* **DPI-C 함수 연동:** Scoreboard는 수집된 메시지 바이트 배열과 바이트 길이, 그리고 현재 추적 중인 초기 해시 벡터(표준 IV 또는 `STATE_IN_0~7` Custom IV)를 인자로 하여 `c_sha256_digest()` 함수를 호출합니다.
* **Custom IV 지원 및 End-to-End 기댓값 산출:** C++ 모델은 전달받은 초기 해시 벡터로 내부 상태를 초기화한 뒤, 소프트웨어 패딩(`0x80` 및 64-bit 비트 길이 추가), Big-Endian 워드 변환, 64라운드 압축 연산을 수행하여 256-bit 기댓값을 반환합니다. Scoreboard는 Custom IV 사용 여부 및 패딩 경계 길이에 따라 테스트 항목을 분류하고 DUT의 `DIGEST_0~7` 결과와 일치 여부를 최종 판정합니다.

# 5. Assertion (SVA) & Functional Coverage Architecture

본 장에서는 SystemVerilog Assertion(SVA)의 배치 구조와 Functional Coverage 수집기의 샘플링 아키텍처를 기술합니다. (개별 SVA Property 및 Covergroup/Bin의 전체 매핑 리스트는 `Verification_Plan.xlsx` 참조)

## 5.1 Assertion (SVA) Hierarchy & Dynamic Control

### 5.1.1 Interface vs. White-Box SVA Binding

SVA는 물리 계층 인터페이스 내장형(Black-box)과 `bind` 구문 기반의 내부 모듈 결합형(White-box)으로 분리되어 동작합니다.

| SVA Module / Interface | Target Instance (`hdl_top`) | Binding Method | Target Domain |
| :--- | :--- | :--- | :---: |
| **`axi4lite_if`** | `AXI4LITE` | Interface Built-in | `AXI4-Lite` |
| **`axis_if`** | `AXIS` | Interface Built-in | `AXI4-Stream` |
| **`core_if`** / **`intr_bfm`** | `CORE` / `INTR_bfm` | Interface Built-in | `Core`, `CSR` |
| **`sha256_core_sva`** | `DUT.u_core` (`sha256_core`) | `bind` (`bind_core_sva`) | `Core` |
| **`sha256_wrapper_sva`** | `DUT` (`sha256_axi_wrapper`) | `bind` (`bind_wrapper_sva`) | `CSR`, `Overall` |

각 SVA 모듈 및 인터페이스의 검증 범위는 다음과 같습니다. (`Verification_Plan.xlsx` 참조)

* **`axi4lite_if` (`AXI4-Lite` Domain):** ARM *AMBA 4 AXI4, AXI4-Lite, and AXI4-Stream Protocol Assertions User Guide*에 정의된 AXI4-Lite 표준 SVA를 감시합니다.
* **`axis_if` (`AXI4-Stream` Domain):** 상기 ARM 공식 가이드에 정의된 AXI4-Stream 표준 SVA를 감시합니다.
* **`core_if` & `intr_bfm` (`Core` & `CSR` Domains):** 비동기 하드웨어 리셋(`!rst_n_i`) 인가 시 코어 제어·해시 상태 출력(`core_if`)과 인터럽트(`intr_bfm`)의 즉시 초기화 여부, 연속 리셋 구간(`!rst_n_i ##1 !rst_n_i`)의 출력 유지(`$stable`), 그리고 코어 제어 신호의 Unknown 방지를 검증합니다.
* **`sha256_core_sva` (`Core` Domain):** 코어 입출력 핸드셰이크(`start_i && ready_o`), `ready_o`/`busy_o` 상호 배타성(Mutex), `INIT` 이후 Busy 구간(`busy_o && !init_o`) 입력 안정성(`p_ctrl_stable`), `done_o` 단일 사이클 펄스 보장, 67사이클 고정 레이턴시, 내부 컨트롤러 파이프라인 시퀀스(`init_o` -> `round_en_o[*64]` -> `update_o` -> `done_o`) 및 Round 카운터를 검증합니다.
* **`sha256_wrapper_sva` (`CSR` & `Overall` Domains):**
  * **CSR:** W1P/W1C 제어 펄스(`ctrl_start_pulse`, `ctrl_soft_reset`, `clear_done_pulse`)의 1사이클 자동 소멸, `CTRL` 읽기 시 상위 예약 비트 및 W1P 비트의 `0` 반환(`p_ctrl_read_zero_w1p`), AXI4-Lite 버스 에러 발생 시 상태 flag 및 인터럽트 격리(`p_sync_err_no_irq`), 쓰기 에러 응답 시 제어/IV 레지스터 값 보존(`p_axi_write_err_atomicity`), 읽기 에러 응답 시 출력 데이터 제로 마스킹(`p_axi_read_err_zero_mask`)을 검증합니다.
  * **Overall:** 비활성화(`!ctrl_en`) 시 `START` 인가 무시(`p_start_ignored_when_disabled`), 내부 버퍼 zeroization, 마지막 코어 연산 시작부터 `status_done`까지의 고정 지연(68사이클), 인터럽트 발생/해제, 코어 연산과 후속 블록 수신/패딩 간의 병렬 동작, 그리고 Soft Reset 및 `TKEEP` 위반 시 내부 FSM·flag·버퍼·`DIGEST`·하위 코어의 초기화를 검증합니다.

### 5.1.2 Dynamic SVA Masking (`disable iff`)

예외 복구 및 에러 주입 테스트 수행 시 정상 프로토콜/타이밍 감시용 SVA가 오발화하는 것을 방지하기 위해 두 가지 런타임 마스킹을 적용합니다.

* **Soft Reset & Protocol Abort Synchronization:** Wrapper의 완료 지연(`p_oa_latency`) 및 병렬 제어 멀티사이클 SVA는 시스템 리셋뿐만 아니라 소프트 리셋(`ctrl_soft_reset`) 및 스트림 프로토콜 에러(`axis_tkeep_err`)에 의한 강제 중단을 처리하기 위해 `disable iff` 조건에 해당 예외 신호를 포함하여 시퀀스 평가를 동기화합니다.
* **Transaction-Scoped SVA Masking in Driver BFM:** `axi4lite_if` 내부의 주소 정렬(`p_addr_alignment_32`) 및 타임아웃(`p_*_timeout`) 프로퍼티는 상시 감시(`0`)를 기본으로 운용됩니다. 비정렬 주소나 타임아웃 예외 주입 시에는 `AXI4LITE_drv_bfm`이 아이템의 에러 flag(`force_unaligned_addr`, `ignore_ready_timeout`)를 확인하여 해당 트랜잭션 구동 구간 동안에만 SVA를 마스킹하고 핸드셰이크 완료 직후 자동 복원합니다.


## 5.2 Functional Coverage Collector Architecture

### 5.2.1 5-Domain Coverage Distribution

전체 Functional Coverage는 프로토콜과 하드웨어 계층에 따라 3개의 Agent 내부 수집기와 2개의 Env 레벨 수집기로 분산 배치됩니다. (각 Covergroup 내 세부 Coverpoint 및 Cross Bin 정의는 `Verification_Plan.xlsx` 참조)

| Coverage Component | Hierarchy Level | Base Class & Input Path | Target Domain |
| :--- | :--- | :--- | :---: |
| **`axi4lite_coverage`** | `m_axi4lite_agent` | `uvm_subscriber`<br>(from `m_monitor.ap`) | `AXI4-Lite` |
| **`axis_coverage`** | `m_axis_agent` | `uvm_subscriber`<br>(from `m_monitor.ap`) | `AXI4-Stream` |
| **`core_coverage`** | `m_core_agent` | `uvm_subscriber`<br>(from `monitor.ap`) | `Core` |
| **`sha256_csr_coverage`** | `sha256_env` | `uvm_subscriber`<br>(from `m_axi4lite_agent.ap`) | `CSR` |
| **`sha256_overall_coverage`** | `sha256_env` | `uvm_component`<br>(`axil_fifo`, `axis_fifo`,<br>`core_fifo`) | `Overall` |

각 Coverage 컴포넌트의 핵심 수집 범위는 다음과 같습니다.

* **`axi4lite_coverage` (`AXI4-Lite` Domain):** 채널 딜레이 교차, `WSTRB`, `AxPROT`, 에러 응답/비정렬 주소 교차를 수집합니다.
* **`axis_coverage` (`AXI4-Stream` Domain):** `tvalid`/`tready` 지연, 패킷 경계 Back-Pressure, `tkeep` 스트로브, 데이터 패턴 및 전송 중 리셋을 수집합니다.
* **`core_coverage` (`Core` Domain):** 512-bit 데이터패스 스트레스 패턴, 블록 체이닝, 리셋 중단 사이클/라운드를 수집합니다.
* **`sha256_csr_coverage` (`CSR` Domain):** 레지스터별 접근/보안 권한, Busy 상태 충돌, WO 읽기 및 미할당 에러, `DONE` 전이를 수집합니다.
* **`sha256_overall_coverage` (`Overall` Domain):** 패딩 경계 길이, 블록 모드×바이트 정렬 교차, 코어 상태별 Soft Reset을 수집합니다.

### 5.2.2 Context-Aware Preprocessing & Sampling Logic

각 Coverage 컴포넌트는 샘플링 시 다음과 같은 전처리를 수행합니다.

1. **RAL 역참조 및 미러 상태 캐싱 결합 (`sha256_csr_coverage`):**
   * 8-bit 물리 주소 오프셋(`{56'd0, t.addr[7:0]}`)을 `CSR_CTRL`, `CSR_STATUS`, `CSR_INTCLEAR`, `CSR_DIGEST`, `CSR_OTHER` 열거형(`csr_reg_e`)으로 추상화합니다 (비정렬 주소 및 미할당 주소는 `CSR_OTHER`로 분류됨).
   * `csr_rb.STATUS.BUSY` 미러 값을 사용하여, Non-secure 읽기 에러(`SLVERR`)에 의한 미러 오염 없이 Busy 상태 교차 커버리지(`cr_busy_prot`)를 측정합니다.
2. **비트 연산 기반 패턴 판별 (`core_coverage`):**
   * 리셋 중단 여부는 `cg_rst`로 상시 기록하고, 정상 완료된 512-bit 입력 블록의 1-bit Hot/Cold 패턴 및 체이닝 여부를 `cg_dp`로 샘플링합니다.
3. **다중 FIFO 연동 기반 페이로드 및 Soft Reset 상태 수집 (`sha256_overall_coverage`):**
   * **`axis_fifo`:** 정상 완료 패킷의 메시지 길이, 전 바이트 `0x80` 패턴 여부, 다중 블록 여부, 마지막 Beat의 워드 정렬 여부를 `cg_payload`로 샘플링합니다.
   * **`core_fifo` & `axil_fifo`:** `core_fifo`로 수신된 코어 연산 중단과 `axil_fifo`로 감지된 Soft Reset 시도를 결합하여 `cg_exception`으로 샘플링합니다.
4. **도달 불가능 조합의 명시적 배제 (`ignore_bins` & Conditional Coverpoints):**
   * 시뮬레이터(`xsim`)의 커버리지 엔진 특성을 고려하여, DUT 미사용 사이드밴드 그룹은 `option.weight = 0`으로 비활성화하고 하드웨어 구조상 발생할 수 없는 조합(AXI4-Lite Slave의 0-cycle 응답, AXI4-Stream DUT의 단기 Back-Pressure·단기 패킷 간격·패킷 중간 부분 스트로브, 매핑된 정상 레지스터 접근 시 `DECERR` 발생 등)을 Waiver합니다.

# 6. Test Suite & Virtual Sequence Architecture

## 6.1 Base Test & Virtual Sequence Infrastructure

모든 테스트는 `sha256_test_base`를 상속받아 공통 검증 환경을 구축하며, 실제 Stimulus 시나리오는 `sha256_base_vseq`에서 파생된 Virtual Sequence를 `vseq.start(null)`로 구동하여 조율합니다. (`m_core_agent`는 Passive Agent이므로 제어 대상에서 제외됩니다.)

* **Base Test Infrastructure (`sha256_test_base`):**
  * **`build_phase()`:** RAL 모델(`csr_rb`) 생성 및 잠금(`lock_model`), 각 Agent Config 기본값 설정, `uvm_config_db` 기반 BFM 핸들 조회 및 배포, 보조 유틸리티(`m_intr_util`, `m_rst_util`) 바인딩을 수행한 뒤 최상위 환경(`m_env`)을 생성합니다.
  * **`report_phase()`:** `uvm_report_server`를 통해 시뮬레이션 전 구간의 `UVM_ERROR` 및 `UVM_FATAL` 발생 건수를 조회하고, 둘 다 `0`일 때만 `[TEST_RESULT]` 태그로 최종 통과 배너(`=== SHA256 UVM TEST PASSED ===`)를 출력합니다.
* **Derived Test Execution & Base Virtual Sequence (`sha256_*_test` & `sha256_base_vseq`):**
  * 각 파생 테스트는 `build_phase()`에서 `super.build_phase()` 호출 후 목적에 맞게 Config 파라미터 및 RAL 리소스 옵션을 오버라이드합니다.
  * `run_phase()`에서는 도메인별 파생 Virtual Sequence(`vseq`)를 생성하고, 아래 표의 `sha256_base_vseq` 핸들을 환경 내 컴포넌트와 연결한 뒤 `vseq.start(null)`을 호출합니다.
  * 모든 파생 Virtual Sequence는 `super.body()`(`sha256_base_vseq::body()`)를 통해 `csr_rb` 및 `intr_proxy` 핸들을 자동 할당받고, `m_cfg.m_rst_util.wait_for_reset_done()`을 호출하여 초기 Power-on Reset(20사이클)이 완전히 해제된 직후의 클록 상승 엣지부터 트랜잭션을 구동합니다. 또한 클록 주기에 독립적인 지연 제어를 위해 `wait_cycles(int cycles = 1)` 헬퍼 태스크를 공통으로 제공합니다.

| `sha256_base_vseq` Handle | Connected Environment Target | Architectural Role |
| :--- | :--- | :--- |
| **`vseq.m_cfg`** | `m_env_cfg` | RAL 블록(`csr_rb`) 및 인터럽트/리셋 유틸리티(`m_intr_util`, `m_rst_util`) 참조 |
| **`vseq.axil_sqr`** | `m_env.m_axi4lite_agent.m_sequencer` | AXI4-Lite 제어 채널 Raw Sequence 및 아이템 구동 경로 |
| **`vseq.axis_sqr`** | `m_env.m_axis_agent.m_sequencer` | AXI4-Stream 데이터 패킷 시퀀스 구동 경로 |

* **Event-Driven Synchronization:** Virtual Sequence는 `intr_proxy.wait_for_interrupt()` 및 `wait_for_clear()`를 통해 인터럽트를 이벤트 기반으로 대기합니다. 단, 초기 Bring-up(`sanity`), 인터럽트 마스킹 검증(`IRQ_EN=0`, `do_oa_disable`), 스트리밍 중 스트레스 인가(`do_oa_stress`) 구간에서만 목적에 맞춰 폴링을 수행합니다.
* **Time-Agnostic Drain Time Management:** 시퀀스 종료 직후 마지막 트랜잭션의 모니터 샘플링 및 Scoreboard 채점이 완료될 수 있도록, 모든 테스트의 `run_phase`는 `vseq.start(null)` 이후 `m_env_cfg.m_rst_util.wait_cycles(*)`을 호출하여 클록 사이클 기반의 Drain Time을 대기한 뒤 Objection을 해제합니다.

## 6.2 Test-Specific Configuration Overrides & Scenarios

검증 목적에 따라 6종의 테스트 클래스는 `build_phase` 및 `run_phase`에서 설정값을 오버라이드합니다.

| Test Class (Virtual Sequence) | `enable_random_delay` (RAL Delay) | `enable_sb_check`* (Hash Scoreboard) | Sim Timeout / Drain Time (`wait_cycles`) |
| :--- | :--- | :--- | :--- |
| **`sha256_sanity_test`** (`sha256_sanity_vseq`) | `0` (0-cycle) | `1` (On) | `1ms` / `100 cycles` |
| **`sha256_axil_test`** (`sha256_axil_vseq`) | `1` (0~20 cycles) | `0` (Off) | `50ms` / `100 cycles` |
| **`sha256_axis_test`** (`sha256_axis_vseq`) | `1` (0~20 cycles) | `0` (Off) | `100ms` / `100 cycles` |
| **`sha256_core_test`** (`sha256_core_vseq`) | `1` (0~20 cycles) | `1` (On) | `50ms` / `500 cycles` |
| **`sha256_csr_test`** (`sha256_csr_vseq`) | `1` (0~20 cycles) | `0` (Off) | `50ms` / `100 cycles` |
| **`sha256_overall_test`** (`sha256_overall_vseq`) | `1` (0~20 cycles) | `1` (On) | `50ms` / `500 cycles` |

*\*참고: `enable_sb_check`는 `DIGEST_0~7` 읽기에 따른 DPI-C 해시 결과 대조만 제어하며, RAL 기반 AXI4-Lite CSR 응답 검증(`check_axil_response`)은 전 테스트 구간에서 상시 동작합니다.*

각 Virtual Sequence를 구성하는 서브 시퀀스 및 태스크별 검증 역할은 다음과 같습니다. (개별 항목의 상세 통과 기준은 `Verification_Plan.xlsx` 참조)

* **`sha256_sanity_vseq` (Basic Bring-up):**
  * `body()`: `ID` 레지스터 확인 후 `"abc"`(3B) 패킷 주입, `STATUS.DONE` 폴링 및 `DIGEST_0~7` 대조를 통한 기본 연결성 확인
* **`sha256_axil_vseq` (AXI4-Lite Protocol):**
  * `axi4lite_protocol_cov_seq`: 채널별 핸드셰이크 딜레이 교차, `WSTRB` 및 `AxPROT` 8종 조합 구동
  * `axi4lite_err_inject_seq`: 비정렬 주소 및 비정상 스트로브 에러 무작위 주입
* **`sha256_axis_vseq` (AXI4-Stream Protocol):**
  * `VIP_DATA_PLANE` / `CPU_CONTROL_PLANE`: CSR 시작·클리어 루프와 병렬로 단일/버스트(`single_seq`, `basic_seq`), Partial/Toggle 패턴(`stream_seq`), 장·단기 지연 및 Back-pressure 타격(`slow_seq`, `short_delay_seq`) 시퀀스 구동
* **`sha256_core_vseq` (SHA-256 Core Standalone):**
  * `do_core_dp_stress()`: 512-bit 데이터패스 스트레스 패턴(All-0/1, Walking-1/0) 및 블록 체이닝 검증
  * `do_core_rst_recovery()`: 코어 연산 전 구간(`0~66` 사이클, `0~63` 라운드) 순차 하드웨어 리셋 인가 및 복구 검증
* **`sha256_csr_vseq` (Wrapper CSR & Firewall):**
  * `do_csr_reset()` / `do_csr_bit_bash()`: RAL 내장 시퀀스 기반 리셋 초기값 및 R/W 비트 접근성 검증 (`build_phase`에서 예외 발생 RO/WO 레지스터 제외)
  * `do_pulse_clear()`: `CTRL` 및 `INTCLEAR`의 W1P·W1C 펄스 자동 소멸 확인
  * `do_addr_err_sweep()`: RO/WO 권한 위반, 미할당 주소, Null Strobe, 비정렬 주소 접근 스윕
  * `do_busy_sweep()`: 연산 중(`STATUS.BUSY == 1`) CSR 변경 차단 및 `SOFT_RESET` 예외 허용 스윕
  * `do_secure_prot()`: Non-secure(`prot[1] == 1`) 접근 차단 방화벽 스윕
  * `do_decouple_sync()`: AXI4-Lite 버스 에러 발생 시 에러 인터럽트 미발생 격리 확인
* **`sha256_overall_vseq` (Top-Level End-to-End Integration):**
  * `do_oa_lifecycle()`: 단일 패킷 기반 제어 수명주기 및 완료 인터럽트 검증
  * `do_oa_e2e_hash()`: 단일/다중 블록 × 워드 정렬/비정렬 교차 가변 길이 해시 및 Auto-Chaining 검증
  * `do_oa_pad_edge()`: 단일/병렬 블록 패딩 경계(55, 56, 64, 119, 120, 128B) 비트 길이 누적 및 `core_done` 동시 완료 경합 스윕
  * `do_oa_all80_edge()`: 패딩 구분자와 동일한 `All-0x80` 페이로드의 9개 경계 길이(1~128B) 해시 정합성 검증
  * `do_oa_manual_chain()`: `STATE_IN_0~7` Custom IV 기반 단일/다중 블록 해시 및 표준 IV 복원 검증
  * `do_oa_b2b_trans()`: 하드웨어 리셋 없는 20회 연속 Back-to-Back 트랜잭션 구동
  * `do_oa_stress()`: 다중 블록 저속 스트리밍 중 비동기 `core_done` 체이닝 및 `STATUS` 연속 폴링 간섭 검증
  * `do_oa_disable()`: `CTRL.EN = 0` 시작 무시·수신 차단 및 `CTRL.IRQ_EN = 0` 완료 인터럽트 마스킹 검증
  * `do_oa_timeout_recov()` / `do_oa_busy_recov()`: `TLAST` 누락(Starvation) 및 코어 Busy(병렬 수신 포함) 중 `SOFT_RESET` 복구 검증
  * `do_oa_tkeep_err()`: 단일 및 병렬 수신 중 비정상 `TKEEP` 하드웨어 차단, 데이터 소거 및 복구 검증
  