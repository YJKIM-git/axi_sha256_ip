# SHA-256 Hardware Accelerator IP Core & UVM 1.2 Verification Environment

본 프로젝트는 **NIST FIPS 180-4** 표준을 준수하는 **AXI4-Lite / AXI4-Stream 기반 SHA-256 하드웨어 가속기 IP(`sha256_axi_wrapper` & `sha256_core`)**의 RTL 설계, **UVM 1.2 Dual-Top 블록 레벨 검증 환경(Sign-off 완료)**, 그리고 **Xilinx Zynq-7000 (`Zybo Z7-20`) FPGA 통합 검증 환경**을 포함합니다.

---

## 1. Key Features & Architecture Overview

### 1.1 Hardware Architecture (`design/`)
시스템 인터페이스 및 패딩 제어를 전담하는 **Wrapper(`sha256_axi_wrapper`)**와 순수 압축 연산을 수행하는 **Core(`sha256_core`)**를 분리 설계하여 재사용성과 보안성을 동시에 확보했습니다.

* **Standard Compliance:** NIST FIPS PUB 180-4 표준 준수 (최대 $2^{64}-1$ bits 메시지 길이 지원)
* **Control Interface (`AXI4-Lite` Slave, 32-bit):**
  * **PeakRDL 기반 CSR Map:** `ID`, `CTRL`, `STATUS`, `INTCLEAR`, `MSG_LEN_LO/HI`, `DIGEST_0~7`, `STATE_IN_0~7` (총 22개 레지스터)
  * **Hardware Security & Exception Firewall:**
    * **PROT Firewall:** Non-secure 접근(`AxPROT[1] == 1`) 시 Write 차단, Read `0x0000_0000` 마스킹 및 `SLVERR(2'b10)` 반환 (`STATUS.ERR_PRT = 1`)
    * **Atomicity Protection:** 연산 중(`STATUS.BUSY == 1`) 설정 변경 시도 차단 및 `SLVERR` 반환 (단, 데드락 복구용 `CTRL.SOFT_RESET` 쓰기는 예외 허용)
    * **Decode Error:** RO 레지스터 쓰기 시 `SLVERR(2'b10)`, WO 레지스터(`INTCLEAR`) 읽기 및 미할당 주소 접근 시 `DECERR(2'b11)` 반환
* **Data Interface (`AXI4-Stream` Slave, 32-bit):**
  * **Hardware Auto-Padding & Byte Swapping:** CPU 개입 없이 `s_axis_tkeep` 기반 바이트 적재, Little-to-Big Endian 변환, `0x80` 패딩 및 64-bit 비트 길이(`msg_len`) 자동 삽입 (55B / 56B / 64B 경계 조건 하드웨어 처리)
  * **TKEEP Protocol Violation Protection:** 패킷 중간 부분 스트로브(`!tlast && tkeep != 4'b1111`), 비연속 Sparse `TKEEP`, Null Beat(`4'b0000`) 감지 시 즉시 버퍼 제로화(`0x00`), `STATUS.ERR_PRT = 1` 설정 및 `S_IDLE` 복귀
* **Compression Engine (`sha256_core`):**
  * **68-Cycle Fixed Latency:** `INIT`(1) $\rightarrow$ `PRE_ROUND`(1) $\rightarrow$ `ROUND`(64) $\rightarrow$ `UPDATE`(1) $\rightarrow$ `DONE`(1)
  * **PPA Optimization:** 16-word(`512-bit`) Circular Queue 기반 Sliding Window 메시지 스케줄러(레지스터 75% 절감) 및 $W_t + K_t$ 파이프라인 래치(`wk_r`) Prefetch 적용
  * **Auto & Manual Chaining:** 다중 블록 자동 피드백 및 `STATE_IN_0~7`을 통한 사용자 정의 IV(Custom IV) 수동 체이닝 지원

### 1.2 UVM 1.2 Verification Environment (`dv/`)
* **Dual-Top Architecture:** 신호 레벨 BFM 계층(`hdl_top`)과 객체 지향 UVM 클래스 계층(`hvl_top`) 분리
* **Custom Reusable VIPs:** Over-provisioning 및 동적 마스킹 구조의 `axi4lite_agent`(Active Master) 및 `axis_agent`(Active Master), 내부 파이프라인 관측용 `core_agent`(Passive)
* **Explicit RAL Prediction:** `sha256_csr.rdl`에서 자동 생성된 RAL 모델과 `uvm_reg_predictor`를 연동하여 버스 에러(`SLVERR`/`DECERR`) 발생 시 미러 값 오염 방지
* **DPI-C Golden Reference Scoreboard:** C++ SHA-256 참조 모델(`c_sha256_digest`)과 실시간 연동하여 End-to-End 해시 무결성 자동 채점
* **ABV (Assertion-Based Verification):** ARM 공식 프로토콜 SVA(`axi4lite_if`, `axis_if`) 및 내부 White-box SVA(`sha256_wrapper_sva`, `sha256_core_sva`) 총 64개 활성 프로퍼티 상시 감시

---

## 2. Verification Sign-off & PPA Summary

### 2.1 Block-Level UVM Verification Sign-off (`Vivado xsim v2025.2`)

| Sign-off Metric | Target | Achieved Result | Status |
| :--- | :---: | :---: | :---: |
| **Regression Suite (6 Tests)** | `0` Warn / Err / Fatal | **`0 Warnings / 0 Errors / 0 Fatals`** (`6 / 6 Tests Passed`, `70m 35s`) | **PASS** |
| **Scoreboard (DPI-C) & RAL Check** | `100%` Match | **`100%`** (`40` Fixed & Random DPI-C Matches + `1` Custom IV Match / `21` Reset + `9` Bit-Bash Checks) | **PASS** |
| **Assertion (SVA) Verification** | `0` Violations | **`0 Violations`** (All `64` Active/Bound Properties Passed across `107` Plan Items) | **PASS** |
| **Functional Coverage (`xcrg`)** | `100%` | **`100.00%`** (`19 / 19` Active Covergroup Instances 100%) | **PASS** |
| **Code Coverage (`xcrg`)** | `100%` Reachable | **Condition: `100.00%`** (`76/76`)<br>**Branch: `99.09%`** (`218/220`, Reachable `100%`)<br>**Toggle: `94.11%`** (Wrapper) / **`100.00%`** (Core Datapath) | **PASS** |

### 2.2 FPGA Implementation & PPA (`Xilinx Zynq-7000 Zybo Z7-20`, `xc7z020-clg400-1`)

| Module Scope | Slices | Slice LUTs | Slice Registers (FF) | F7 / F8 Muxes | $F_{max}$ (WNS) | Core Peak Throughput | Dynamic Power (PL) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`sha256_core` (Core Only)** | 620 | 1,753 | 1,097 | 192 / 64 | `100 MHz` | **752.9 Mbps** | - |
| **`sha256_axi_wrapper` (Top)** | 1,063 | 3,420 | 2,308 | 213 / 64 | `100 MHz` (`+0.128 ns`) | **752.9 Mbps** *(Core)* | **0.037 W** |

---

## 3. Documentation Index (`docs/`)

프로젝트의 모든 설계 및 검증 문서는 `docs/` 하위에서 관리됩니다.

| Document Category | File Path | Description |
| :--- | :--- | :--- |
| **Hardware Specification (MAS)** | [`docs/Micro_Architecture_Specification.pdf`](docs/Micro_Architecture_Specification.pdf) | 핀 설명, CSR 메모리 맵, 보안/예외 처리 사양, 패딩/코어 FSM 타이밍 및 FPGA PPA 분석서 |
| **Verification Specification** | [`docs/SHA256_Verification_Specification.pdf`](docs/SHA256_Verification_Specification.pdf) | UVM 1.2 Dual-Top 아키텍처, VIP/Agent 구조, RAL, DPI-C Scoreboard, SVA 및 커버리지 사양서 |
| **Verification Plan (5 Domains)** | [`docs/Verification_Plan.xlsx`](docs/Verification_Plan.xlsx) | 5대 도메인(`axil`, `axis`, `core`, `csr`, `overall`) 총 107개 검증 항목, 33개 Waiver 및 참조 가이드(`Summary`) |
| **Verification Sign-off Report** | [`docs/SHA256_Verification_Report.pdf`](docs/SHA256_Verification_Report.pdf) | 6종 회귀 테스트 결과, SVA/기능/코드 커버리지 달성 지표, 미달성 코드 Waiver 분석 및 RTL Bug Fix 리포트 |
| **Merged Coverage & Sim Logs** | [`docs/Coverage_rpt/functionalCoverageReport/dashboard.html`](docs/Coverage_rpt/functionalCoverageReport/dashboard.html)<br>[`docs/Coverage_rpt/codeCoverageReport/dashboard.html`](docs/Coverage_rpt/codeCoverageReport/dashboard.html)<br>[`docs/Coverage_rpt/log/`](docs/Coverage_rpt/log/) | `xcrg` 병합 Functional Coverage(100%) / Code Coverage HTML 리포트 및 6종 테스트 시뮬레이션 원본 로그 |
| **AXI4-Lite VIP Docs** | [`docs/vip/axil_vip/axil_user_guide.md`](docs/vip/axil_vip/axil_user_guide.md)<br>[`docs/vip/axil_vip/axil_vip_architecture.md`](docs/vip/axil_vip/axil_vip_architecture.md)<br>[`docs/vip/axil_vip/AXI4LITE_Verification_Plan.xlsx`](docs/vip/axil_vip/AXI4LITE_Verification_Plan.xlsx) | AXI4-Lite Master VIP 사용자 가이드, 내부 아키텍처 명세서 및 독립 검증 계획서 |
| **AXI4-Stream VIP Docs** | [`docs/vip/axis_vip/axis_user_guide.md`](docs/vip/axis_vip/axis_user_guide.md)<br>[`docs/vip/axis_vip/axis_vip_architecture.md`](docs/vip/axis_vip/axis_vip_architecture.md)<br>[`docs/vip/axis_vip/AXIS_Verification_Plan.xlsx`](docs/vip/axis_vip/AXIS_Verification_Plan.xlsx) | AXI4-Stream VIP 사용자 가이드, 내부 아키텍처 명세서 및 독립 검증 계획서 |

---

## 4. Directory Structure

```text
uvm_sha256/
├── design/                                 # RTL Design Sources (SystemVerilog)
│   ├── sha256_axi_wrapper.sv               # Top Wrapper (AXI4-Lite CSR, AXI4-Stream Rx, Auto-Padding FSM)
│   └── sha256_core/                        # 68-Cycle SHA-256 Compression Engine & Submodules (14 files)
├── docs/                                   # Specifications, Test Plans, Reports & Coverage Archives
│   ├── Coverage_rpt/                       # xcrg HTML Reports (codeCoverageReport, functionalCoverageReport) & Sim Logs
│   ├── FPGA/                               # FPGA Verification Report (.md) & System Block Diagram Figures
│   ├── MAS/                                # Micro Architecture Specification (.docx, .md, figures/, wavedrom/)
│   ├── Micro_Architecture_Specification.pdf
│   ├── Verification_Plan.xlsx              # 5-Domain Integrated Test Plan & Waiver List (7 Tabs)
│   ├── Verif_report/                       # Verification Sign-off Report (.docx, .md)
│   ├── SHA256_Verification_Report.pdf
│   ├── Verif_Spec/                         # Verification Specification (.docx, .md, figures/)
│   └── vip/                                # Standalone VIP Documentation (axil_vip/, axis_vip/)
├── dv/                                     # Verification Environments (UVM 1.2 & Static TB)
│   ├── agents/                             # Reusable UVM Agents & BFM/Interface Layers
│   │   ├── axi4lite_agent/                 # AXI4-Lite Master VIP, RAL Adapter & SVA/Coverage (not_used/: Utility Seqs)
│   │   ├── axis_agent/                     # AXI4-Stream VIP & SVA/Coverage (not_used/: Loopback/Slave BFM Archive)
│   │   └── core_agent/                     # SHA-256 Core White-Box Passive Agent, Monitor BFM & Coverage
│   ├── bl_tb/                              # Block-Level Top UVM Testbench
│   │   ├── env/                            # sha256_env, env_config, DPI-C Scoreboard, Overall Coverage
│   │   ├── ref_model/                      # C++ Golden Reference Model (sha256_ref_model.cpp)
│   │   ├── register_model/                 # PeakRDL Autogenerated RAL Package (sha256_reg_pkg.sv) & CSR Coverage
│   │   ├── sequences/                      # Virtual Sequence Library (sanity, axil, axis, core, csr, overall)
│   │   ├── sim/                            # Simulation & Coverage Merge Makefile
│   │   ├── tb/                             # Dual-Top (hdl_top.sv, hvl_top.sv) & White-Box SVA (wrapper_sva, core_sva)
│   │   └── test/                           # UVM Test Classes (6 Test Suites)
│   ├── static_tb/                          # Standalone Directed Testbench
│   │   ├── sim/                            # Vivado Simulator (xsim) Makefile
│   │   └── tb_sha256_tkeep.sv              # TKEEP Strobe Boundary & Zero-Padding Directed TB
│   └── utils/                              # Auxiliary BFM & Proxy Utilities (interrupt/, reset/)
├── fpga/                                   # Xilinx Zybo Z7-20 FPGA Implementation & Firmware
│   ├── bd/                                 # Zynq PS + AXI DMA + SHA-256 PL Block Design (zybo.bd)
│   ├── firmware/                           # Bare-metal C Drivers (DMA, HAL, SD parser, Ref model) & Handoff (.xsa)
│   ├── Makefile                            # FPGA Implementation Automation Makefile
│   ├── script/                             # Vivado TCL Scripts & Test Vector Preprocessor
│   ├── synth/                              # Physical & Timing Constraints (constraint.xdc)
│   └── test_vector/                        # NIST CAVP Standard Response (.rsp) & Preprocessed Binaries (.BIN)
├── rdl/                                    # SystemRDL Register Specification & PeakRDL Makefile
│   ├── Makefile
│   └── sha256_csr.rdl
├── Makefile                                # Top-Level Automation Makefile (all, bl_tb, static_tb, fpga, peakrdl, clean)
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

### 5.2 Running UVM Simulations & Coverage Generation
`dv/bl_tb/sim/` 디렉토리(또는 최상위 `Makefile`)에서 단일 테스트 실행, 전체 6종 회귀 테스트 구동 및 커버리지 병합 리포트 생성을 수행합니다.

```bash
# 1. 시뮬레이션 디렉토리 이동
cd dv/bl_tb/sim

# 2. 단일 UVM 테스트 실행 (예: sha256_sanity_test, sha256_overall_test 등)
make run TEST=sha256_sanity_test

# 3. 6종 전체 회귀 테스트(Regression) 실행, 로그 요약(rpt_log) 및 xcrg 커버리지 병합
make run_all

# 4. 시뮬레이션 로그 판정 요약만 재확인
make rpt_log
```

**Supported `TEST` Targets:**
* `sha256_sanity_test` : `"abc"`(3B) 표준 벡터 기반 기본 E2E 해시 연산 및 환경 Bring-up
* `sha256_axil_test` : AXI4-Lite 프로토콜 커버리지(채널 딜레이 교차, `WSTRB`, `AxPROT`) 및 에러 주입 검증
* `sha256_axis_test` : AXI4-Stream 5-Phase 데이터/제어 병렬 구동 및 스트림 프로토콜 커버리지 검증
* `sha256_core_test` : 512-bit 데이터패스 4대 스트레스 패턴 및 0~68사이클 전 구간 비동기 리셋 타격/복구 검증
* `sha256_csr_test` : RAL `hw_reset` / `bit_bash`, W1P/W1C 펄스 소멸, Busy 충돌, Non-secure 방화벽 및 미할당 주소 검증
* `sha256_overall_test` : 55/56/64B 패딩 경계, 가변 길이 체이닝, Custom IV, B2B/Stall 스트레스, `TKEEP` 보호 및 Soft Reset 복구 통합 검증

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
