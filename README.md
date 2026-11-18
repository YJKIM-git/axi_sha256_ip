# SHA-256 Hardware Accelerator IP Core & UVM 1.2 Verification Environment

본 프로젝트는 **NIST FIPS 180-4** 표준을 준수하는 **AXI4-Lite / AXI4-Stream 기반 SHA-256 하드웨어 가속기 IP(`sha256_axi_wrapper` & `sha256_core`)**의 RTL 설계, **UVM 1.2 Dual-Top 블록 레벨 검증 환경(Sign-off 완료)**, **핀 레벨 정적 테스트벤치**, 그리고 **Xilinx Zynq-7000 (`Zybo Z7-20`) FPGA SoC 통합 검증 환경**을 포함합니다.

---

## 1. Key Features & Architecture Overview

### 1.1 Hardware Architecture (`design/`)
시스템 인터페이스, 보안 방화벽 및 하드웨어 자동 패딩을 전담하는 **Wrapper(`sha256_axi_wrapper`)**와 순수 압축 연산을 수행하는 **Core(`sha256_core`)**를 분리 설계하여 모듈 재사용성과 시스템 보안성을 동시에 확보했습니다.

* **Standard Compliance:** NIST FIPS PUB 180-4 표준 준수 ($1\text{ Byte}$ [$8\text{ bits}$] ~ 최대 $2^{64}-1\text{ bits}$ 메시지 길이 지원)
* **Control Interface (`AXI4-Lite` Slave, 32-bit):**
  * **PeakRDL 기반 CSR Map:** `ID`, `CTRL`, `STATUS`, `INTCLEAR`, `MSG_LEN_LO/HI`, `DIGEST_0~7`, `STATE_IN_0~7` (총 22개 레지스터)
  * **Hardware Security & Exception Firewall:**
    * **PROT Firewall:** Non-secure 접근(`AxPROT[1] == 1`) 시 주소와 무관하게 Write 차단, Read `0x0000_0000` 제로 마스킹 및 `SLVERR(2'b10)` 최우선 반환
    * **Atomicity Protection:** 연산 중(`STATUS.BUSY == 1`) `STATE_IN_0~7` 및 비-리셋 `CTRL` 쓰기 시도(동일 설정값 및 부분 스트로브 포함) 차단 및 `SLVERR(2'b10)` 반환 (단, 데드락 복구용 `CTRL.SOFT_RESET` 쓰기는 `OKAY` 예외 허용 및 표준 IV 즉시 복원)
    * **Alignment, Decode & Permission Error:** 비정렬 주소(`AxADDR[1:0] != 2'b00`) 접근 및 RO 레지스터 쓰기 시 `SLVERR(2'b10)`, WO 레지스터(`INTCLEAR`) 읽기 및 미할당 주소(`0x18~0x1F`, `0x40~0x7F`, `0xA0~0xFF`) 접근 시 `DECERR(2'b11)` 반환 및 읽기 `0x0000_0000` 제로 마스킹 (제어 버스 에러는 에러 인터럽트 `irq_o` 및 `STATUS.ERR_PRT`와 격리)
* **Data Interface (`AXI4-Stream` Slave, 32-bit):**
  * **Overlapped Streaming & Hardware Auto-Padding:** 코어 입력 홀드 레지스터(`core_block_reg`)와 수신 버퍼(`block_b`)를 분리하여 이전 블록 코어 연산(67 사이클) 중 후속 블록 수신(`S_RCV`) 및 패딩을 병렬 수행(`block_pending` 연속 기동)하며, CPU 개입 없이 Little-to-Big Endian 변환, `0x80` 패딩 및 64-bit 비트 길이(`msg_len`)를 자동 삽입 (단일 블록 `55/56/64B` 및 다중 블록 `119/120/128B` 경계 조건 하드웨어 처리)
  * **TKEEP Protocol Violation Protection:** 패킷 중간 부분 스트로브(`!tlast && tkeep != 4'b1111`), 마지막 Beat 비연속 Sparse `TKEEP`, 또는 Null Beat(`4'b0000`) 감지 시 즉시 수신 버퍼·홀드 레지스터·다이제스트(`DIGEST_0~7`)·카운터(`byte_cnt`, `msg_len`) 제로화(`0x00`), 하위 코어 동시 리셋(`core_rst_n`), `STATUS.ERR_PRT = 1` 설정 및 에러 인터럽트(`irq_o = 1`) 발생 후 `S_IDLE` 복귀
* **Compression Engine (`sha256_core`):**
  * **67-Cycle Fixed Latency:** `INIT`(1) $\rightarrow$ `ROUND`(64) $\rightarrow$ `UPDATE`(1) $\rightarrow$ `DONE`(1)의 3-Process Moore FSM 구조
  * **Datapath & Timing Optimization:** 16-word(`512-bit`) 시프트 레지스터(`w_mem`) 기반 메시지 스케줄러(`sha256_message_schedule`, 64-word 버퍼 대비 레지스터 75% 절감) 및 중간 합산 노드 기반 균형 Adder Tree(`sha256_round_logic`) 적용
  * **Auto & Manual Chaining:** 다중 블록 자동 피드백 및 `STATE_IN_0~7`을 통한 사용자 정의 IV(Custom IV) 수동 체이닝 지원

### 1.2 UVM 1.2 Verification Environment (`dv/`)
* **Dual-Top Architecture:** 신호 레벨 BFM 계층(`hdl_top`)과 객체 지향 UVM 클래스 계층(`hvl_top`) 분리
* **Custom Reusable VIPs:** Over-provisioning 및 동적 비트 마스킹 구조의 `axi4lite_agent`(Active Master, 트랜잭션 단위 동적 SVA 마스킹 지원) 및 `axis_agent`(Active Master), 내부 파이프라인 관측용 `core_agent`(Passive)
* **Explicit RAL Prediction:** `sha256_csr.rdl`에서 자동 생성된 PeakRDL RAL 모델과 `uvm_reg_predictor`를 연동하여 버스 에러(`SLVERR`/`DECERR`) 발생 시 미러 값 오염 원천 방지
* **DPI-C Golden Reference & Always-On CSR Scoreboard:** C++ 참조 모델(`c_sha256_digest`, 표준 및 Custom IV 지원) 연동 해시 채점과 함께, 6종 테스트 전 구간에서 RAL 주소 역참조(`get_reg_by_offset`) 및 필드 권한(`get_access`) 기반 AXI4-Lite 응답 코드·읽기 제로 마스킹 상시 검증(`check_axil_response`) 수행
* **ABV (Assertion-Based Verification):** ARM 공식 프로토콜 SVA(`axi4lite_if`, `axis_if`), 리셋/인터럽트 SVA(`core_if`, `intr_bfm`) 및 내부 White-box SVA(`sha256_wrapper_sva`, `sha256_core_sva`) 총 76개 활성 프로퍼티(+ 1 EOS Check) 상시 감시

---

## 2. Verification Sign-off & PPA Summary

### 2.1 Block-Level UVM Verification Sign-off (`Vivado xsim v2025.2`)

| Sign-off Metric | Target | Achieved Result | Status |
| :--- | :---: | :--- | :---: |
| **Regression Suite (6 UVM Tests)** | `0` Warn / Err / Fatal | **`0 Warnings / 0 Errors / 0 Fatals`** (`6 / 6 Tests Passed`, `90m 51s`) | **PASS** |
| **Scoreboard (DPI-C & CSR) / RAL** | `100%` Match | **`100%`** (`62` DPI-C Hash Matches [`60` Std + `2` Custom IV] / `2,358` AXIL Resp Checks / `21` Reset + `9` Bit-Bash Checks / `31/31` Static TB Cases) | **PASS** |
| **Assertion (SVA) Verification** | `0` Violations | **`0 Violations`** (All `76` Active Properties + `1` EOS Check Passed across `114` Plan Items) | **PASS** |
| **Functional Coverage (`xcrg`)** | `100%` | **`100.00%`** (`19 / 19` Active Covergroup Instances 100%) | **PASS** |
| **Code Coverage (`xcrg`)** | `100%` Reachable | **Condition: `100.00%`** (`100/100`, All Modules)<br>**Branch: `99.42%`** (`171/172`, Reachable `100%`)<br>**Toggle: `65.43%`** (6-File Avg, `6,354/8,122` Bits `78.23%`, Datapath/MsgSched `100%`) | **PASS** |

### 2.2 FPGA Implementation & PPA (`Xilinx Zynq-7000 Zybo Z7-20`, `xc7z020-clg400-1`)

| Module Scope | Slices | Slice LUTs | Slice Registers (FF) | F7 Muxes | $F_{max}$ (WNS @ `100 MHz`) | Peak / Measured Throughput | Dynamic Power (PL) |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- | :---: |
| **`sha256_core` (Core Only)** | 518 | 1,611 | 1,041 | 0 | `100 MHz` | **764.18 Mbps** *(67 cyc Peak)* | - |
| **`sha256_axi_wrapper` (Top)** | 937 | 2,820 | 2,766 | 19 | `116.43 MHz` (`+1.411 ns`) | **752.94 Mbps** *(68 cyc Peak)*<br>**605.23 Mbps** *(SoC Measured, `20.31x` vs. PS)* | **0.039 W**<br>*(Total On-Chip `1.581 W`)* |

---

## 3. Documentation Index (`docs/`)

프로젝트의 모든 설계 및 검증 문서는 `docs/` 하위에서 관리됩니다.

| Document Category | File Path | Description |
| :--- | :--- | :--- |
| **Hardware Specification (MAS)** | [`docs/MAS/Micro_Architecture_Specification.md`](docs/MAS/Micro_Architecture_Specification.md) | 핀 설명, CSR 메모리 맵, 보안/예외 처리 사양, 병렬 패딩/67사이클 코어 FSM 타이밍 및 FPGA PPA 분석서 |
| **Verification Specification** | [`docs/Verif_Spec/SHA256_Verification_Specification.md`](docs/Verif_Spec/SHA256_Verification_Specification.md) | UVM 1.2 Dual-Top 아키텍처, VIP/Agent 구조, RAL, DPI-C Scoreboard, SVA 및 커버리지 사양서 |
| **Verification Plan (5 Domains)** | [`docs/Verification_Plan.xlsx`](docs/Verification_Plan.xlsx) | 5대 도메인(`axil`, `axis`, `core`, `csr`, `overall`) 총 114개 UVM 항목, 12개 Directed/FPGA 항목(`direct`), 32개 Waiver 및 3개 Note(`waiver_list`) |
| **Verification Sign-off Report** | [`docs/Verif_Report/SHA256_Verification_Report.md`](docs/Verif_Report/SHA256_Verification_Report.md) | 6종 회귀 테스트 결과, SVA/기능/코드 커버리지 달성 지표, 미달성 코드 Waiver 분석 및 8건의 RTL Bug Fix 리포트 |
| **FPGA Verification Report** | [`docs/FPGA_report/SHA256_FPGA_Verification_Report.md`](docs/FPGA_report/SHA256_FPGA_Verification_Report.md)<br>[`fpga/firmware/README.md`](fpga/firmware/README.md) | Zynq-7000 SoC 연동, NIST CAVP 128종 스트리밍 검증, 방화벽 Data Abort 예외 테스트 및 성능 벤치마크 보고서 / 펌웨어 기술 레퍼런스 |
| **Merged Coverage & Sim Logs** | [`docs/Coverage_Report/cov_report/functionalCoverageReport/dashboard.html`](docs/Coverage_Report/cov_report/functionalCoverageReport/dashboard.html)<br>[`docs/Coverage_Report/cov_report/codeCoverageReport/dashboard.html`](docs/Coverage_Report/cov_report/codeCoverageReport/dashboard.html)<br>[`docs/Coverage_Report/`](docs/Coverage_Report/) | `xcrg` 병합 Functional Coverage(100%) / Code Coverage HTML 리포트 및 6종 테스트 시뮬레이션 원본 로그(`xsim_*.log`) |
| **AXI4-Lite VIP Docs** | [`docs/VIP/axil_vip/axil_user_guide.md`](docs/VIP/axil_vip/axil_user_guide.md)<br>[`docs/VIP/axil_vip/axil_vip_architecture.md`](docs/VIP/axil_vip/axil_vip_architecture.md)<br>[`docs/VIP/axil_vip/AXI4LITE_Verification_Plan.xlsx`](docs/VIP/axil_vip/AXI4LITE_Verification_Plan.xlsx) | AXI4-Lite Master VIP 사용자 가이드, 내부 아키텍처 명세서 및 독립 검증 계획서 |
| **AXI4-Stream VIP Docs** | [`docs/VIP/axis_vip/axis_user_guide.md`](docs/VIP/axis_vip/axis_user_guide.md)<br>[`docs/VIP/axis_vip/axis_vip_architecture.md`](docs/VIP/axis_vip/axis_vip_architecture.md)<br>[`docs/VIP/axis_vip/AXIS_Verification_Plan.xlsx`](docs/VIP/axis_vip/AXIS_Verification_Plan.xlsx) | AXI4-Stream VIP 사용자 가이드, 내부 아키텍처 명세서 및 독립 검증 계획서 |

---

## 4. Directory Structure

```text
sha256/
├── design/                                 # RTL Design Sources (SystemVerilog)
│   ├── sha256_axi_wrapper.sv               # Top Wrapper (AXI4-Lite CSR/Firewall, AXI4-Stream Rx, Auto-Padding FSM)
│   └── sha256_core/                        # 67-Cycle SHA-256 Compression Engine & Submodules (6 files)
│       ├── sha256_pkg.sv                   # FIPS 180-4 Bitwise Functions, K_ROM & SHA256_IV Constants
│       ├── sha256_core.sv                  # Core Top Module
│       ├── sha256_controller.sv            # 67-Cycle 3-Process Moore FSM & Round Counter
│       ├── sha256_datapath.sv              # 256-bit Working State Registers & Hash Accumulator
│       ├── sha256_message_schedule.sv      # 16-Word Shift-Register Message Scheduler (W_t)
│       └── sha256_round_logic.sv           # Balanced Adder-Tree Round Compression Logic
├── docs/                                   # Specifications, Test Plans, Reports & Coverage Archives
│   ├── Coverage_Report/                    # xcrg HTML Reports (codeCoverageReport, functionalCoverageReport) & Sim Logs
│   ├── FPGA_report/                        # FPGA Verification Report (SHA256_FPGA_Verification_Report.md)
│   ├── MAS/                                # Micro Architecture Specification (Micro_Architecture_Specification.md)
│   ├── Verification_Plan.xlsx              # 5-Domain Integrated Test Plan, Direct/FPGA & Waiver List (8 Sheets)
│   ├── Verif_Report/                       # Verification Sign-off Report (SHA256_Verification_Report.md)
│   ├── Verif_Spec/                         # Verification Specification (SHA256_Verification_Specification.md)
│   └── VIP/                                # Standalone VIP Documentation (axil_vip/, axis_vip/)
├── dv/                                     # Verification Environments (UVM 1.2 & Static TB)
│   ├── agents/                             # Reusable UVM Agents & BFM/Interface Layers
│   │   ├── axi4lite_agent/                 # AXI4-Lite Master VIP, RAL Adapter & SVA/Coverage
│   │   ├── axis_agent/                     # AXI4-Stream VIP & SVA/Coverage
│   │   └── core_agent/                     # SHA-256 Core White-Box Passive Agent, Monitor BFM & Coverage
│   ├── bl_tb/                              # Block-Level Top UVM Testbench
│   │   ├── env/                            # sha256_env, env_config, DPI-C Scoreboard, Overall Coverage
│   │   ├── ref_model/                      # C++ Golden Reference Model (sha256_ref_model.cpp)
│   │   ├── register_model/                 # PeakRDL Autogenerated RAL Package (sha256_reg_pkg.sv) & CSR Coverage
│   │   ├── sequences/                      # Virtual Sequence Library (sanity, axil, axis, core, csr, overall)
│   │   ├── sim/                            # UVM Simulation & Coverage Merging Makefile
│   │   ├── tb/                             # Dual-Top (hdl_top.sv, hvl_top.sv) & White-Box SVA (wrapper_sva, core_sva)
│   │   └── test/                           # UVM Test Classes (6 Test Suites)
│   ├── static_tb/                          # Standalone Directed Pin-Level Testbench
│   │   ├── sim/                            # Directed Testbench Simulation Makefile
│   │   └── tb_sha256_tkeep.sv              # Null Beat (TKEEP=4'b0000) & 27-Pattern Invalid TKEEP Sweep TB
│   └── utils/                              # Auxiliary BFM & Proxy Utilities (interrupt/, reset/)
├── fpga/                                   # Xilinx Zybo Z7-20 FPGA Implementation & Firmware
│   ├── bd/                                 # Zynq PS + AXI DMA + SHA-256 PL Block Design (zybo.bd)
│   ├── firmware/                           # Bare-metal C Drivers (DMA, HAL, SD parser, Ref model), README & Handoff (.xsa)
│   ├── Makefile                            # FPGA Implementation Automation Makefile
│   ├── script/                             # Vivado TCL Scripts & Test Vector Preprocessor (preprocess_rsp.py)
│   ├── synth/                              # Physical & Timing Constraints (constraint.xdc)
│   └── test_vector/                        # NIST CAVP Standard Response (.rsp) & Preprocessed Binaries (.BIN)
├── rdl/                                    # SystemRDL Register Specification & PeakRDL Makefile
│   ├── Makefile
│   └── sha256_csr.rdl
├── Makefile                                # Top-Level Automation Makefile
├── verible.filelist                        # Verible SystemVerilog Linter Filelist
└── README.md

```

---

## 5. Toolchain Requirements & Quick Start

### 5.1 Prerequisites

* **OS:** Ubuntu 24.04 LTS (or WSL2 on Windows 11)
* **EDA Tool:** Xilinx Vivado Design Suite **v2025.2** (`xvlog`, `xelab`, `xsim`, `xsc`, `xcrg`, `vivado`)
* **Register Generator:** `PeakRDL` (`pip install peakrdl peakrdl-uvm`)
* **C++ Compiler & Linter:** `g++` (C++17 support for DPI-C), `verible-verilog-lint` (Optional)

### 5.2 Running UVM Simulations & Directed Testbench

`dv/bl_tb/sim/` 디렉토리(또는 최상위 `Makefile`)에서 단일 UVM 테스트 실행, 전체 6종 회귀 테스트 구동 및 커버리지 병합 리포트 생성을 수행합니다.

```bash
# 1. UVM 시뮬레이션 디렉토리 이동
cd dv/bl_tb/sim

# 2. 단일 UVM 테스트 실행 (예: sha256_sanity_test, sha256_overall_test 등)
make run TEST=sha256_sanity_test

# 3. 6종 전체 회귀 테스트(Regression) 실행, 로그 요약(rpt_log) 및 xcrg 커버리지 병합
make run_all

# 4. 시뮬레이션 로그 판정 요약만 재확인
make rpt_log

# 5. 핀 레벨 정적 테스트벤치(tb_sha256_tkeep.sv, 31 Cases) 단독 실행
cd ../../static_tb/sim
make all

```

**Supported UVM `TEST` Targets:**

* `sha256_sanity_test` : `"abc"`(3B) 표준 벡터 기반 기본 E2E 해시 연산 및 환경 Bring-up
* `sha256_axil_test` : AXI4-Lite 프로토콜 커버리지(채널 딜레이 교차, `WSTRB`, `AxPROT` 8종) 및 에러 주입 검증
* `sha256_axis_test` : AXI4-Stream 데이터/제어 병렬 구동(단일/버스트, Partial/Toggle, 장·단기 지연 및 Back-pressure 타격) 검증
* `sha256_core_test` : 512-bit 데이터패스 스트레스 패턴(All-0/1, Walking-1/0) 및 0~66사이클(0~63라운드) 전 구간 리셋 타격/복구 검증
* `sha256_csr_test` : RAL `hw_reset` / `bit_bash`, W1P/W1C 펄스 소멸, Busy 충돌/Hang 복구 스윕, Non-secure 방화벽, 미할당 주소 및 버스 에러 인터럽트 격리 검증
* `sha256_overall_test` : 단일/병렬 블록 패딩 경계(`55/56/64/119/120/128B`) 및 `core_done` 경합 스윕, `All-0x80` 9개 경계 길이(`1~128B`), Custom IV 단일/다중 블록 체이닝, 20회 B2B 및 Stall 폴링 스트레스, 제어 비활성화(`EN=0` 시작 무시/차단, `IRQ_EN=0` 마스킹), 비정상 `TKEEP` 차단 및 Soft Reset 복구 통합 검증

### 5.3 Regenerating UVM RAL Model from SystemRDL

`rdl/sha256_csr.rdl` 수정 시 PeakRDL을 통해 UVM 레지스터 모델(`sha256_reg_pkg.sv`)을 재생성합니다.

```bash
cd rdl
make

```

### 5.4 Building FPGA Bitstream (`Zybo Z7-20`)

`fpga/` 디렉토리에서 IP 패키징, Zynq 블록 디자인 구성 및 비트스트림 합성을 일괄 수행합니다.

```bash
cd fpga
make all

```
