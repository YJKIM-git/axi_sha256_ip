# Verification Sign-off Report
# UVM 1.2 Block-Level Verification Sign-off for SHA-256 IP Core

### Table of Contents

- **1. Verification Sign-off Summary**
  - 1.1 Sign-off Criteria & Achievement Status
  - 1.2 Simulation Environment & Reference Documents
- **2. Regression Test & Scoreboard Results**
  - 2.1 Test Suite Execution Summary (`rpt_log` & Resource Metrics)
  - 2.2 UVM Report ID & Scoreboard Verification Summary
- **3. Coverage & Assertion Closure Analysis**
  - 3.1 Functional Coverage Summary (`xcrg` Merged Report)
  - 3.2 Assertion (SVA) Verification Summary
  - 3.3 Code Coverage Summary (`xcrg` Merged Report)
    - 3.3.1 DUT Module-Level Code Coverage Breakdown
    - 3.3.2 Uncovered Code Analysis & Waiver Justifications
  - 3.4 Verification Plan Waivers & Technical Justifications
- **4. RTL Bug Report**
  - 4.1 RTL Design Bugs Found & Fixed


# 1. Verification Sign-off Summary

## 1.1 Sign-off Criteria & Achievement Status
본 문서는 `Micro_Architecture_Specification.pdf`(MAS)에 정의된 SHA-256 하드웨어 가속기(`sha256_axi_wrapper` 및 `sha256_core`)에 대해 `SHA256_Verification_Specification.pdf` 1.4절의 정량적 Sign-off 기준 달성 여부를 기록한 최종 검증 보고서입니다.

| Sign-off Category | Sign-off Criteria (`Verification Spec 1.4`) | Target | Final Result | Status |
| :--- | :--- | :---: | :---: | :---: |
| **Regression Status** | 전체 6종 테스트 스위트 실행 시 `UVM_WARNING`, `UVM_ERROR`, `UVM_FATAL` 발생 건수 | `0` | **`0 Warnings / 0 Errors / 0 Fatals`**<br>(6 / 6 Tests Passed) | **PASS** |
| **Scoreboard & RAL Check** | DPI-C 참조 모델(`c_sha256_digest`) 해시 비교 일치율 및 RAL 내장 시퀀스(`hw_reset`, `bit_bash`) 통과율 | `100%` | **`100%`**<br>(40 Fixed & Random DPI-C Matches + 1 Custom IV Match / 21 Reset + 9 Bit-Bash Checks) | **PASS** |
| **Assertion (SVA) Status** | 시뮬레이션 전 구간 프로토콜 및 내부 White-box SVA 위반(`ERROR: Assertion failed.`) 발생 건수 | `0` | **`0 Violations`**<br>(All 64 SVA Properties Passed) | **PASS** |
| **Functional Coverage** | 5대 검증 도메인 병합(`xcrg`) 기준 활성 Covergroup 달성률 (`Groups Coverage Summary`) | `100%` | **`100.00%`**<br>(Score: `100`, Inst Score: `100` / 19 Active Instances) | **PASS** |
| **Code Coverage** | RTL 설계 전체(`design/*`, Wrapper + Core 15 Modules, 29 Instances) 대상 Branch / Condition / Toggle 커버리지 | `100%`<br>(Reachable) | **Condition: `100.00%`** (`76/76`, Wrapper+Core)<br>**Branch: `99.09%`** (`218/220`, Reachable `100%`)<br>**Toggle: `94.11%`** (Wrapper) / **`100%`** (Core Datapath) | **PASS** |


## 1.2 Simulation Environment & Reference Documents
검증 결과의 재현성(Reproducibility) 보장을 위한 실행 환경 사양과 상위 참조 문서 목록은 다음과 같습니다.

- **Simulation & Coverage Tool Chain (`Makefile`):**
  - **Simulator & Compiler:** Xilinx Vivado Simulator (`xsim v2025.2`, 64-bit, SW Build 6299465), DPI-C Compiler (`xsc`), Elaborator (`xelab -L uvm -timescale 1ns/10ps -debug typical -cc_type line,tgl,branch -sv_lib dpi`)
  - **Coverage Merger:** Xilinx Coverage Report Generator (`xcrg -cov_db_dir ./ -report_dir ./cov_report -ccExclusionFile ./cc_exclude.txt`)
  - **System Clock & Seed:** `100 MHz` (`10 ns` period), Default Deterministic Seed (`1`)
- **Reference Documents & Standards:**
  - **프로토콜 및 알고리즘 표준:** NIST FIPS 180-4, NIST CAVP SHAVS (Byte-Oriented Test Vectors), ARM IHI0022 (AXI4-Lite), ARM DUI0534B (AMBA 4 Protocol Assertions User Guide), AMD UG1037 (Vivado AXI Reference Guide)
  - **하드웨어 설계 사양서:** `Micro_Architecture_Specification.pdf`
  - **검증 아키텍처 사양서:** `SHA256_Verification_Specification.pdf`
  - **통합 검증 계획서 (5 UVM Domains, Directed/FPGA Closure & Waivers):** `Verification_Plan.xlsx` (`Summary`, `axil`, `axis`, `core`, `csr`, `overall`, `direct`, `waiver_list` Sheets)
  - **FPGA 타겟 통합 검증 보고서:** `SHA256_FPGA_Verification_Report.pdf` (Zynq-7000 SoC Bring up, NIST CAVP 전수 검증 및 PPA 분석)
  - **VIP 개발 명세서 및 가이드:** `axil_vip_architecture.md`, `axil_user_guide.md`, `axis_vip_architecture.md`, `axis_user_guide.md`

# 2. Regression Test & Scoreboard Results

## 2.1 Test Suite Execution Summary (`rpt_log` & Resource Metrics)

| Test Name (`UVM_TESTNAME`) | Target Domain | `UVM_INFO` | `UVM_WARNING` | `UVM_ERROR` | `UVM_FATAL` | `SVA` Fail | Wall-Clock Elapsed | Result |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`sha256_sanity_test`** | Bring-up / Sanity | 8 | 0 | 0 | 0 | 0 | `2 s` (`05:52:42` ~ `05:52:44`) | **PASS** |
| **`sha256_axil_test`** | AXI4-Lite VIP | 9 | 0 | 0 | 0 | 0 | `4 s` (`05:52:45` ~ `05:52:49`) | **PASS** |
| **`sha256_axis_test`** | AXI4-Stream VIP | 10 | 0 | 0 | 0 | 0 | `1,150 s` (`05:52:51` ~ `06:12:01`) | **PASS** |
| **`sha256_csr_test`** | CSR (Wrapper) | 47 | 0 | 0 | 0 | 0 | `2,515 s` (`06:12:02` ~ `06:53:57`) | **PASS** |
| **`sha256_core_test`** | Core (Engine) | 20 | 0 | 0 | 0 | 0 | `9 s` (`06:53:59` ~ `06:54:08`) | **PASS** |
| **`sha256_overall_test`** | Overall (E2E) | 65 | 0 | 0 | 0 | 0 | `555 s` (`06:54:09` ~ `07:03:24`) | **PASS** |
| **Total / Summary** | **5 Domains (107 Plan Rows)** | **159** | **0** | **0** | **0** | **0** | **`4,235 s` (`70m 35s`)** | **100% PASS** |

> **Supplemental Directed Testbench Execution (`dv/static_tb/tb_sha256_tkeep.sv`, `Verification_Plan.xlsx` `direct` Sheet `[DIR-01]~[DIR-03]`):** UVM VIP 제약 및 Xilinx AXI DMA 하드웨어 구조상 구동이 제한되는 Null Beat(`TKEEP = 4'b0000`, `[WV-AXIS-09]`)와 패킷 중간/마지막 Beat의 비정상 `(TLAST, TKEEP)` 27종 진리표 전 조합(`[WV-AXIS-11]`, `[OA-14]`)을 종결하기 위해 별도의 SVA 기반 정적 테스트벤치를 구동했습니다. 시뮬레이션 결과(`13,945 ns`, CPU Time `0.83 s`), 총 **31 / 31 테스트 케이스(Null Beat 3건, 27종 전수 스윕 27건, 에러 소거 후 `"abc"` Golden 해시 복구 1건) 및 5종 White-box SVA가 `0 Error`로 100% PASS**했습니다.

## 2.2 UVM Report ID & Scoreboard Verification Summary
각 테스트 로그(`xsim_*.log`) 하단의 `--- UVM Report Summary --- (Report counts by id)`에 집계된 검증 판정 및 시퀀스 구동 통계는 다음과 같습니다 (`UVM_VERBOSITY = UVM_LOW` 기준).

| UVM Report ID Tag (`[ID]`) | Source Component / Sequence | `sanity` | `axil` | `axis` | `csr` | `core` | `overall` | Total Count |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`[oa_byte_swap / Datapath]`** | `sha256_scoreboard::compare_hash()` | 1 | - | - | - | 1 | 30 | **32** |
| **`[oa_pad_edge]`** | `sha256_scoreboard::compare_hash()` | - | - | - | - | 4 | 4 | **8** |
| **`[uvm_reg_hw_reset_seq]`** | `sha256_csr_vseq::do_csr_reset()` | - | - | - | 21 | - | - | **21** |
| **`[uvm_reg_bit_bash_seq]`** | `sha256_csr_vseq::do_csr_bit_bash()` | - | - | - | 9 | - | - | **9** |
| **`[VSEQ_OA]`** | `sha256_overall_vseq` | - | - | - | - | - | 22 | **22** |
| **`[VSEQ / VSEQ_CORE / AXIS / AXIL]`** | Domain Virtual Sequences | - | 2 | 3 | 8 | 8 | 2 | **23** |
| **`[TEST_RESULT]`** | `sha256_test_base::report_phase()` | 1 | 1 | 1 | 1 | 1 | 1 | **6** |
| **`[UVM System & Test Lifecycle]`** | UVM Kernel & `uvm_test_top` (`RNTST`, `TEST_DONE` 등) | 6 | 6 | 6 | 8 | 6 | 6 | **38** |
| **Total (`UVM_INFO` Sum)** | **All Components (`2.1절` 일치)** | **8** | **9** | **10** | **47** | **20** | **65** | **159** |

**Verification Meaning (Report ID별 검증 의미):**

- **`[oa_byte_swap / Datapath]` (`32`):** 고정 벡터(3B) 및 가변 길이 무작위(Random) 패킷(4B, 13B, 16B, 130B, 372B)의 DPI-C 해시 일치 횟수
- **`[oa_pad_edge]` (`8`):** 패딩 경계 길이(55B, 56B, 64B) 무작위 패킷 및 코어 스트레스 패턴(64B×4)의 DPI-C 해시 일치 횟수
- **`[uvm_reg_hw_reset_seq]` (`21`):** WO(`INTCLEAR`) 제외 전체 21개 CSR 레지스터의 하드웨어 리셋 초기값(표준 IV 등) 대조 완료
- **`[uvm_reg_bit_bash_seq]` (`9`):** RW 권한 9개 레지스터(`STATE_IN_0~7`, `CTRL`)의 비트 단위 0/1 교차 쓰기/읽기 검증 완료
- **`[VSEQ_OA]` (`22`):** Overall 서브 시퀀스 단계별 진입 로그(14건) 및 제어 차단(`EN=0`, `IRQ_EN=0`)·예외 복구(`TKEEP` 에러, Starvation, Busy Reset) 자체 검증(Self-Check) 통과 확인 로그(8건)
- **`[VSEQ / VSEQ_CORE / AXIS / AXIL]` (`23`):** 각 도메인 Virtual Sequence 및 하위 검증 태스크(Reset, Bit-bash, Error Sweep, DP Stress 등)의 시작/종료 마일스톤 로그
- **`[TEST_RESULT]` (`6`):** `=== SHA256 UVM TEST PASSED ===` 최종 판정 배너 출력
- **`[UVM System & Test Lifecycle]` (`38`):** 각 테스트 시작/종료 시 출력되는 UVM 프레임워크 기본 상태 보고(`UVM/RELNOTES`, `NO_DPI_TSTNAME`, `RNTST`, `UVM/COMP/NAMECHECK`, `TEST`, `TEST_DONE` 각 6건 및 `csr_test` 내 `STARTING_SEQ` 2건)

> **Scoreboard 및 RAL 검증 집계 요약:** 전체 회귀 테스트 동안 총 215회의 코어 압축 시작(`S_START_CORE`) 및 144회의 코어 블록 연산 완료(`core_done`)가 수행되었으며, E2E 결과 대조를 통해 **총 40건의 DPI-C 참조 모델 해시 일치(`32 + 8`, 고정 및 무작위 페이로드)**, **1건의 Custom IV 수동 체이닝 기댓값 일치(`do_oa_manual_chain`)**, 그리고 **총 30건의 RAL 내장 시퀀스 점검(`21 Reset + 9 Bit-Bash`)**을 100% 달성했습니다.


# 3. Coverage & Assertion Closure Analysis

## 3.1 Functional Coverage Summary (`xcrg` Merged Report)
6종 테스트의 커버리지 DB를 병합한 `groups.html` 리포트 기준, 전체 24개 선언 그룹 중 32-bit DUT 환경에서 활성화된 **19개 Covergroup 인스턴스가 모두 100%를 달성하여 최종 `Groups Coverage Summary Score: 100%` (`Inst Score: 100%`)를 기록**했습니다.

| Report ID (`groups.html`) | Domain | Covergroup Name | Num Instances | Score (%) |
| :--- | :--- | :--- | :---: | :---: |
| **`grp0`** | AXIL VIP | `axi4lite_agent_pkg::cg_axi4lite_32b_normal` | 1 | **100%** |
| **`grp1`** | AXIL VIP | `axi4lite_agent_pkg::cg_axi4lite_32b_error` | 1 | **100%** |
| **`grp4`** | AXIS VIP | `axis_agent_pkg::cg_routing_matrix_type` | 1 | **100%** |
| **`grp5`** | AXIS VIP | `axis_agent_pkg::cg_routing_change_type` | 1 | **100%** |
| **`grp6`** | AXIS VIP | `axis_agent_pkg::cg_data_pattern_type` | 1 | **100%** |
| **`grp7`** | AXIS VIP | `axis_agent_pkg::cg_backpressure_corner_type` | 1 | **100%** |
| **`grp8`** | AXIS VIP | `axis_agent_pkg::cg_byte_qualifier_type_partial` | 1 | **100%** |
| **`grp10`** | AXIS VIP | `axis_agent_pkg::cg_tkeep_tstrb_type_partial` | 1 | **100%** |
| **`grp12`** | AXIS VIP | `axis_agent_pkg::cg_sideband_type_mixed` | 1 | **100%** |
| **`grp14`** | AXIS VIP | `axis_agent_pkg::axis_coverage::cg_handshake` | 1 | **100%** |
| **`grp15`** | AXIS VIP | `axis_agent_pkg::axis_coverage::cg_packet_boundary` | 1 | **100%** |
| **`grp16`** | AXIS VIP | `axis_agent_pkg::axis_coverage::cg_reset` | 1 | **100%** |
| **`grp17`** | AXIS VIP | `axis_agent_pkg::axis_coverage::cg_null_transfer` | 1 | **100%** |
| **`grp18`** | Core | `core_agent_pkg::core_coverage::cg_dp` | 1 | **100%** |
| **`grp19`** | Core | `core_agent_pkg::core_coverage::cg_rst` | 1 | **100%** |
| **`grp20`** | CSR | `sha256_env_pkg::sha256_csr_coverage::cg_csr_protocol` | 1 | **100%** |
| **`grp21`** | CSR | `sha256_env_pkg::sha256_csr_coverage::cg_hw_update` | 1 | **100%** |
| **`grp22`** | Overall | `sha256_env_pkg::sha256_overall_coverage::cg_payload` | 1 | **100%** |
| **`grp23`** | Overall | `sha256_env_pkg::sha256_overall_coverage::cg_exception` | 1 | **100%** |
| **Summary** | **All 5 Domains** | **19 Active Instantiated Groups (`Inst Score: 100%`)** | **19** | **100%** |

**Verification Target Summary (Covergroup별 검증 대상 요약):**

- **`grp0` (`cg_axi4lite_32b_normal`):** 32-bit 정상 R/W, `OKAY`, `WSTRB`, `PROT`(8종), 5채널 딜레이 및 `AW×W` 교차
- **`grp1` (`cg_axi4lite_32b_error`):** 32-bit R/W 방향별 에러 응답(`SLVERR`, `DECERR`) 및 비정렬 주소 교차
- **`grp4` (`cg_routing_matrix_type`):** 라우팅 ID/DEST 기본 상태 확인 (DUT 미사용 핀으로 Cross Waiver 적용)
- **`grp5` (`cg_routing_change_type`):** 패킷 경계 라우팅 변경 확인 (`option.weight = 0` Waiver 적용)
- **`grp6` (`cg_data_pattern_type`):** 32-bit `All_0`, `All_1`, `Toggle`(`32'h5555_5555`) × `TLAST`(`0`/`1`) 교차
- **`grp7` (`cg_backpressure_corner_type`):** `TLAST` 인접 여부(`away_from_tlast`, `near_tlast`) × 코어 연산 장기 Back-Pressure(`long`) 교차
- **`grp8` (`cg_byte_qualifier_type_partial`):** `TLAST=0, All-1` 및 `TLAST=1, All-1 / Partial` 바이트 스트로브 조합
- **`grp10` (`cg_tkeep_tstrb_type_partial`):** 활성 바이트 폭 내 `TKEEP` 및 `TSTRB` 일치 조건(`all_1_match`, `partial_match`)
- **`grp12` (`cg_sideband_type_mixed`):** `TUSER` 사이드밴드 그룹 (`option.weight = 0` Waiver 적용)
- **`grp14` (`cg_handshake`):** `cp_valid_wait`(0~extreme) × `cp_ready_wait`(`0`, `extreme` 69클록 Back-Pressure) 교차
- **`grp15` (`cg_packet_boundary`):** 단일(1-Beat) 및 버스트(Multi-Beat) 패킷 × 패킷 간 간격(`cp_ipg`) 교차
- **`grp16` (`cg_reset`):** 정상 전송(`clean_reset`) 및 전송 중 비동기 리셋(`active_transfer_reset`) 도달
- **`grp17` (`cg_null_transfer`):** 정상 바이트 전송(`normal`) × 패킷 경계(`not_last`, `last`) 교차
- **`grp18` (`cg_dp`):** 512-bit `All-0`, `All-1`, `Walking-1`, `Walking-0` 패턴 및 단일/체이닝 블록(`cp_chain`)
- **`grp19` (`cg_rst`):** 리셋 중단 여부, 중단 사이클(`0~68` 69개 Bin), 중단 라운드(`0~63` 64개 Bin) 전수 도달
- **`grp20` (`cg_csr_protocol`):** 레지스터 분류, 방향, 응답, 보안(`PROT`), Busy 상태 및 3대 예외 교차(`cr_wo_err`, `cr_busy_prot`, `cr_secure_prot`)
- **`grp21` (`cg_hw_update`):** 코어 연산 완료 시 `STATUS.DONE` 필드의 `0 => 1` 상승 전이
- **`grp22` (`cg_payload`):** 패딩 경계(`55B`, `56B`, `64B`), 단일/다중 블록 × 워드 정렬/비정렬(`cr_block_align`) 4개 교차
- **`grp23` (`cg_exception`):** 스트림 대기 중 Soft Reset(`rst_while_idle`) 및 코어 연산 중 Soft Reset(`rst_while_busy`)

> *미생성 조건부 그룹 (5개, `Num Instances = 0`):* `grp2`(`cg_axi4lite_64b_normal`), `grp3`(`cg_axi4lite_64b_error`), `grp9`(`cg_byte_qualifier_type_no_partial`), `grp11`(`cg_tkeep_tstrb_type_no_partial`), `grp13`(`cg_sideband_type_no_mixed`)은 64-bit 전용 또는 8-bit 이하/`TUSER` 미사용 조건부 그룹으로 본 32-bit 설정에서는 인스턴스화되지 않으며 전체 점수 집계에서도 자동 제외됩니다.


## 3.2 Assertion (SVA) Verification Summary
인터페이스 내장형 SVA와 `bind` 기반 White-box SVA 총 64개 활성 프로퍼티에 대한 검증 요약입니다 (개별 프로퍼티 명세는 `Verification_Plan.xlsx` 참조).

| SVA Module / Interface | Binding Target (`hdl_top`) | Plan Reference (`Verification_Plan.xlsx`) | Property Count | Failure Count (`rpt_log`) | Status |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **`axi4lite_if.sv`** | `AXI4LITE` (Built-in) | `axil` Sheet (`[AXIL-01]` ~ `[AXIL-24]`) | `23` Active<br>(24 Declared, `[AXIL-17]` 64b Disabled) | `0` | **PASS** |
| **`axis_if.sv`** & `axis_monitor` | `AXIS` (Built-in & `check_phase`) | `axis` Sheet (`[AXIS-01]` ~ `[AXIS-12]`) | `20` Active SVA<br>(+ `1` EOS `check_phase`, ARM 28종 대응) | `0` | **PASS** |
| **`core_if.sv`** & `intr_bfm.sv` | `CORE`, `INTR_bfm` (Built-in) | `core` Sheet (`[CORE-08, 14, 15]`), `csr` Sheet (`[CSR-01]`) | `4` | `0` | **PASS** |
| **`sha256_wrapper_sva.sv`** | `DUT` (`bind_wrapper_sva`) | `csr` Sheet (`[CSR-04]`), `overall` Sheet (`[OA-03, 04, 05, 11, 15]`) | `8` | `0` | **PASS** |
| **`sha256_core_sva.sv`** | `DUT.u_core` (`bind_core_sva`) | `core` Sheet (`[CORE-01]` ~ `[CORE-07]`, `[CORE-18, 19]`) | `9` | `0` | **PASS** |
| **Total / Summary** | **All Interfaces & DUT Submodules** | **5 Domains** | **`64` Active SVA**<br>(+ `1` EOS Check) | **`0`** | **100% PASS** |


## 3.3 Code Coverage Summary (`xcrg` Merged Report)

### 3.3.1 DUT Module-Level Code Coverage Breakdown
`cc_exclude.txt`를 통해 검증 대상 RTL(총 15개 파일, 15개 모듈, 29개 인스턴스)에 한정하여 수집된 `xcrg` Code Coverage(**Branch / Condition / Toggle**) 최종 달성 현황입니다 (`dashboard.html` 및 `modules.html` 기준).

| Mod ID | Module Name (`modules.html`) | Inst Count | Branch Score (%) | Condition Score (%) | Toggle Score (%) |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **`mod1`** | **`sha256_axi_wrapper_0`** (`hdl_top.DUT`) | 1 | **`99.21%`** (`126/127`) | **`100.00%`** (`66/66`) | **`94.11%`** (`4,224/4,488`) |
| **`mod2`** | **`sha256_core_0`** (`DUT.u_core`) | 1 | N/A (`0/0`) | N/A (`0/0`) | **`45.45%`** (`10/22`) |
| **`mod3`** | **`sha256_datapath`** (`u_core.u_datapath`) | 1 | **`100.00%`** (`11/11`) | **`100.00%`** (`2/2`) | **`100.00%`** |
| **`mod4`** | **`sha256_sig0`** (`u_message_schedule.u_sig0`) | 1 | N/A (`0/0`) | N/A (`0/0`) | **`100.00%`** |
| **`mod5`** | **`sha256_sig1`** (`u_message_schedule.u_sig1`) | 1 | N/A (`0/0`) | N/A (`0/0`) | **`100.00%`** |
| **`mod6`** | **`sha256_round_logic`** (`u_datapath.u_round_logic`) | 1 | N/A (`0/0`) | N/A (`0/0`) | **`90.00%`** (`576/640`) |
| **`mod8`** | **`sha256_controller`** (`u_core.u_controller`) | 1 | **`90.91%`** (`10/11`) | **`100.00%`** (`4/4`) | `0.00%` (`0/14`)* |
| **`mod9`** | **`sha256_message_schedule`** (`u_message_schedule`) | 1 | **`100.00%`** (`6/6`) | **`100.00%`** (`4/4`) | **`27.12%`** (`408/1,504`)* |
| **`mod10`** | **`sha256_ep0`** (`u_round_logic.u_ep0_mod`) | 1 | N/A (`0/0`) | N/A (`0/0`) | **`100.00%`** |
| **`mod11`** | **`sha256_ep1`** (`u_round_logic.u_ep1_mod`) | 1 | N/A (`0/0`) | N/A (`0/0`) | **`100.00%`** |
| **`mod13`** | **`sha256_k_rom`** (`u_datapath.u_k_rom`) | 1 | **`100.00%`** (`65/65`) | N/A (`0/0`) | N/A (`0/0`) |
| **`mod7, 12, 14, 15`** | **`add32` (6), `rotr` (10), `ch` (1), `maj` (1)** | 18 | N/A (`0/0`) | N/A (`0/0`) | N/A (`0/0`) |
| **Total** | **15 RTL Modules (`dashboard.html`)** | **29** | **`99.09%`** (`218/220`) | **`100.00%`** (`76/76`) | **`75.67%`** (10-Mod Avg)<br>**`50.44%`** (15-Mod Raw) |

**Module Role & Coverage Note (모듈별 역할 및 커버리지 비고):**

- **`mod1` (`sha256_axi_wrapper_0`):** Top Wrapper, AXI-Lite CSR, Padding FSM (`default` 분기 1건 외 전 분기/조건 100% 달성)
- **`mod2` (`sha256_core_0`):** Core Top Wrapper (`round_idx_o` 6비트 와이어 외 제어 신호 5종 100%)
- **`mod3` (`sha256_datapath`):** Core Datapath, Working State (`a~h`), Pre-calculation (`wk_r`)
- **`mod4` (`sha256_sig0`) / `mod5` (`sha256_sig1`):** Message Schedule $\sigma_0(x)$ / $\sigma_1(x)$ Combinational Logic
- **`mod6` (`sha256_round_logic`):** Compression Round Logic (`t1_o` 제외 9개 32-bit 연산 신호 100%)
- **`mod8` (`sha256_controller`):** 68-Cycle Controller FSM (`default` 분기 1건 외 전 상태/조건 100%)
- **`mod9` (`sha256_message_schedule`):** 16-Word Sliding Window (`w_m2/m7/m15`, `sig0/1_w`, `schedule_w` 100%)
- **`mod10` (`sha256_ep0`) / `mod11` (`sha256_ep1`):** Round Logic $\Sigma_0(a)$ / $\Sigma_1(e)$ Combinational Logic
- **`mod13` (`sha256_k_rom`):** 64-Entry Round Constant ($K_t$) Lookup ROM (`case` 65개 분기 100%)
- **`mod7, 12, 14, 15` (`add32`, `rotr`, `ch`, `maj`):** 포트 선언만 존재하는 조합회로 (상위 `mod6`/`mod4,5,10,11`에서 100% 검증)
- **Total Summary:** Condition `100%` / 유효 Branch `100%` 달성 (미달성 항목 하단 분석)

> **참고 (`xcrg` 모듈 평균 산출 특성):** `mod2~mod7`, `mod10~mod12`, `mod14~mod15`의 Branch/Condition `N/A (0/0)` 표기는 모듈 내부에 분기문(`if`/`case`)이 존재하지 않음(`No Branches/Conditions in Module`)을 의미하며 전체 Branch/Condition 점수 분모에서 제외됩니다. 반면 Toggle Coverage의 경우, 내부 `logic` 변수 선언 없이 입출력 포트로만 구성된 5개 조합 회로 모듈(`mod7, 12, 13, 14, 15`, Total Toggle Bits `0/0`)이 `modules.html`에서 `0%`로 표기되어 15개 모듈 단순 산술 평균(`756.68 / 15 = 50.44%`)을 낮추는 요인으로 작용합니다 (내부 신호가 존재하는 10개 모듈 기준 평균은 `75.67%`).

### 3.3.2 Uncovered Code Analysis & Waiver Justifications
전체 RTL 모듈 중 미달성(Uncovered)으로 남은 **Branch 2건(`218/220`)**과 **Toggle 미계측 신호**에 대한 전수 분석 및 기술적 Waiver 사유는 다음과 같습니다.

| No. | Target Module & Scope | Coverage Type | Uncovered Target / Signal | Waiver Category |
| :---: | :--- | :---: | :--- | :---: |
| **1** | **`sha256_axi_wrapper`** (`fsm_logic`)<br>**`sha256_controller`** (`case(state_r)`) | Branch<br>(2 / 220) | • `default: state <= S_IDLE;` (`Branch 127`)<br>• `default: state_r <= STATE_IDLE;` (`Branch 11`) | **Defensive Code**<br>(Unreachable) |
| **2** | **`sha256_axi_wrapper`** (`fsm_logic`) | Toggle | • `msg_len[63:12]` & `msg_len[2:0]` (`All Other bits of msg_len`, 55 bits) | **Spec & Structural Constraint** |
| **3** | **`sha256_axi_wrapper`** (`fsm_logic`)<br>**`sha256_message_schedule`** | Toggle | • `integer i` (32-bit Loop Index) | **Synthesizable Loop Variable** |
| **4** | **`sha256_message_schedule`** (`mod9`) | Toggle | • `reg [31:0] w_mem[0:15]` (512 bits) | **Tool Limitation**<br>(`xsim` 2D Unpacked Array) |
| **5** | **`sha256_axi_wrapper`** (`mod1`) | Toggle | • `wdata_reg[31:0]`, `wstrb_reg[3:0]`<br>• `awprot_reg[2:0]`, `arprot_reg[2:0]`<br>• `state[2:0]` | **Tool Artifact**<br>(Verified by Driven Regs & Cond Cov) |
| **6** | **`sha256_core`** (`mod2`)<br>**`sha256_controller`** (`mod8`)<br>**`sha256_message_schedule`** (`mod9`) | Toggle | • `round_idx_r[5:0]`, `round_idx_o[5:0]`<br>• `repeat_last_round_r`<br>• `slot_i[3:0]` | **Tool Artifact**<br>(Verified by `k_rom` & `slot_m*` 100%) |
| **7** | **`sha256_round_logic`** (`mod6`) | Toggle | • `t1_o[31:0]` (32 bits) | **Tool Artifact**<br>(Verified by `sum1` & `next_a/e_w` 100%) |

**Root Cause & Technical Justification (항목별 상세 원인 및 Waiver 근거):**

1. **`sha256_axi_wrapper` (`fsm_logic`) & `sha256_controller` (`case(state_r)`) — Branch (2 / 220):**
   - **합성 안전성 확보용 FSM Default 분기:** 리셋 시 `IDLE`로 초기화되고 정의된 유효 상태(`S_IDLE~S_DONE` 및 `STATE_IDLE~STATE_DONE`)로만 전이하도록 설계되어 정상 및 리셋 시뮬레이션에서는 도달 불가능함.
2. **`sha256_axi_wrapper` (`fsm_logic`) — `msg_len[63:12]` & `msg_len[2:0]` Toggle:**
   - **하위 3비트(`[2:0]`):** 바이트 단위 수신에 따라 항상 8비트의 배수(`{valid_bytes, 3'b000}`)만 가산되므로 구조상 상수 `0`으로 고정됨.
   - **중위 9비트(`[11:3]`):** RTL 시뮬레이션에서 최대 372B($2,976\text{ bits}$) 스트리밍을 통해 `1B`($8\text{ bits}$)~`256B`($2,048\text{ bits}$) 구간인 **`msg_len[11:3]` 9개 비트는 100% Toggle을 달성**함.
   - **상위 52비트(`[63:12]`):** 최대 $2^{64}-1\text{ bits}$ 스펙 지원용 상위 카운터 비트로 RTL 시뮬레이션 시간 제약상 전 비트 토글이 비현실적임. 단, `[OA-02]`에서 `MSG_LEN_LO/HI` 레지스터 Read를 통해 64-bit 누적 값 및 상위 워드(`32'h0`) 연결 정합성을 검증 완료하였으며, **후속 FPGA 하드웨어 검증(`SHA256_FPGA_Verification_Report.md` 2.3절)에서 NIST `SHA256LongMsg.rsp` 최대 길이($49,616\text{ bits} = 6,202\text{ Bytes}$) 스트리밍을 통과하여 `msg_len[15:3]` 구간까지의 하드웨어 동작 무결성을 추가로 입증**함.
3. **`sha256_axi_wrapper` (`fsm_logic`) & `sha256_message_schedule` — `integer i` Toggle:**
   - **합성 시 병렬 배선으로 풀리는 `for` 루프 인덱스:** 리셋 및 블록 적재 시 `for (i = 0; i < 64; i++)` 구문에서 배열 인덱싱에만 사용되는 문법용 변수로, 플립플롭이 생성되지 않으나 `xsim`이 모듈 변수로 인식하여 `0%`로 표기한 항목임.
4. **`sha256_message_schedule` (`mod9`) — `reg [31:0] w_mem[0:15]` Toggle:**
   - **2차원 언팩 배열에 대한 시뮬레이터 토글 미계측:** `xsim`/`xcrg`는 32-bit × 16개로 선언된 2차원 메모리 배열(`w_mem[0:15]`)의 개별 비트 토글을 추적하지 않고 `All bits of w_mem = 0`으로 일괄 표기함. 그러나 `[CORE-13]`에서 `512'h0` 및 `512'hFFFF...`를 직접 적재했고, **동일 모듈 내에서 `w_mem` 배열을 그대로 읽는 출력 와이어 `w_m2`, `w_m7`, `w_m15`가 모두 `100% Toggle`을 달성**하여 512비트 전 비트의 물리적 토글이 증명됨.
5. **`sha256_axi_wrapper` (`mod1`) — `wdata_reg`, `wstrb_reg`, `aw/arprot_reg`, `state` Toggle:**
   - **`wdata_reg` & `wstrb_reg`:** 해당 래치 값을 그대로 대입받는 `state_in_reg[0:7]`(256 bits)이 `mod1`에서 **`100% Toggle`을 달성**함.
   - **`aw/arprot_reg`:** `[AXIL-28]`에서 `AxPROT` 8종(`3'b000~3'b111`) 기능 커버리지 **100% 달성** 및 `mod1` Condition Coverage(`aw/arprot_reg[1]==1` TRUE/FALSE) **100% 달성**으로 검증됨.
   - **`state`:** `state` 값을 그대로 복사받는 `ret_state[2:0]`가 **`100% Toggle`을 달성**하고 `case(state)`의 전 유효 분기가 실행됨.
6. **`sha256_core` (`mod2`), `sha256_controller` (`mod8`), `sha256_message_schedule` (`mod9`) — `round_idx_r/o`, `repeat_last_round_r`, `slot_i` Toggle:**
   - **`round_idx_r/o`:** 해당 카운터를 주소 입력으로 받는 `sha256_k_rom`(`mod13`)의 **64개 라운드 상수 `case` 분기(`0~63`)가 `100% (65/65)` 실행**되었고, `core_coverage`(`cp_aborted_round` `0~63`) 100% 달성으로 전 비트 동작이 증명됨.
   - **`repeat_last_round_r`:** `mod8` Branch Coverage(`if (repeat_last_round_r)`: 147 TRUE / 148 FALSE)를 통해 `0 <-> 1` 전환이 147회 이상 발생함이 증명됨.
   - **`slot_i`:** 동일한 `round_idx_i[3:0]`에서 상수 오프셋만 뺀 `slot_m2`, `slot_m7`, `slot_m15`가 `mod9`에서 **`100% Toggle`을 달성**함.
7. **`sha256_round_logic` (`mod6`) — `t1_o[31:0]` Toggle:**
   - **중간 합산 포트 와이어 미계측:** `t1_o`를 생성하는 직전 가산기 와이어 `sum1[31:0]`과, `t1_o`를 입력받아 최종 라운드 출력을 생성하는 후단 와이어 **`next_a_w[31:0]`(`t1_o + t2_o`) 및 `next_e_w[31:0]`(`d_i + t1_o`)이 모두 `mod6`에서 `100% Toggle`을 달성**하여 전 비트 활성 동작이 증명됨.


## 3.4 Verification Plan Waivers & Technical Justifications
`Verification_Plan.xlsx`의 `waiver_list` 시트에 등록된 총 33건(Partial Waiver 15건, Full Waiver 18건)의 도메인별 Waiver 요약입니다.

| Domain | Waiver ID Range | Waived Item / Target | Waiver Level |
| :--- | :--- | :--- | :--- |
| **AXI4-Lite VIP** | `[WV-AXIL-01~03]` | `p_addr_alignment_32`, `p_*_timeout`<br>`p_addr_alignment_64`, `cg_axi4lite_64b_*` | Partial Waiver<br>Waiver (N/A) |
| **AXI4-Lite VIP** | `[WV-AXIL-04~08]` | `AW/W/B/AR/R_DELAY` (`back_to_back = {0}`)<br>`ERR_RESP` (`decerr = {2'b11}`) | Partial Waiver (`ignore_bins`) |
| **AXI4-Stream VIP** | `[WV-AXIS-01~06]`<br>`[WV-AXIS-12~18]` | `TID`, `TDEST`, `TSTRB`, `TUSER` SVA 및 CG<br>`DATA_WIDTH <= 8` (`_no_partial`), Zero-width | Waiver / Partial Waiver |
| **AXI4-Stream VIP** | `[WV-AXIS-07~11]` | `cg_handshake`, `cg_backpressure_corner` 단기 Back-Pressure<br>`cg_packet_boundary` (`0~5`클록 IPG)<br>`TLAST=0 & Partial`, `TKEEP=0` (`cg_null_transfer`) | Partial Waiver / Waiver (`ignore_bins`) |
| **Core** | `[WV-CORE-01~04]` | `ctrl_ignore` (`[CORE-09]`), `dp_fips` (`[CORE-10]`)<br>`dp_rand` (`[CORE-11]`), `rst_async` (`[CORE-17]`) | Waiver (Delegated to Wrapper & FPGA) |
| **CSR** | `[WV-CSR-01~03]` | `INTCLEAR` in `hw_reset_seq` (`[CSR-01]`)<br>RO/WO Regs in `bit_bash_seq` (`[CSR-02]`)<br>`csr_hw_update` (`[CSR-08]`, `cg_hw_update`) | Partial Waiver / Waiver (Delegated) |

**Technical Justification Summary (도메인별 Waiver 사유 요약):**

- **AXI4-Lite VIP (`[WV-AXIL-01~03]`):**
  - 기본값은 `0`(상시 감시)으로 운용하되, 에러 주입 구간에서만 일시적으로 `1`로 마스킹 후 복구.
  - DUT는 32-bit 고정 데이터 폭(`DATA_WIDTH=32`)이므로 64-bit 전용 SVA 및 CG는 미적용.
- **AXI4-Lite VIP (`[WV-AXIL-04~08]`):**
  - DUT의 `s_axi_*ready` 및 `bvalid/rvalid`가 `always_ff` 레지스터 출력이므로 0-cycle 응답 불가.
  - 주소 맵에 종속적인 `DECERR` 검증은 CSR 도메인(`[CSR-05, 06]`)으로 이관하여 수집.
- **AXI4-Stream VIP (`[WV-AXIS-01~06]`, `[WV-AXIS-12~18]`):**
  - SHA-256 DUT에 라우팅/스트로브/사이드밴드 포트가 존재하지 않음 (MAS 4.1.2절).
  - 32-bit 고정 폭 환경이므로 단일 바이트(`<=8-bit`) 및 Width 0 조건은 해당 사항 없음.
- **AXI4-Stream VIP (`[WV-AXIS-07~11]`):**
  - DUT 코어 연산 Back-Pressure는 16 Beats마다 고정 69클록(`extreme`/`Long`)으로만 발생하므로 단기 Back-Pressure 제외.
  - 패킷 간 코어 연산 및 CSR 제어 오버헤드로 인해 `0~5`클록 IPG 발생 불가.
  - 패킷 중간 Partial `TKEEP` 및 Null Beat(`4'b0000`)는 정상 스트림 프로토콜 커버리지에서는 제외하고 예외 보호 시나리오(`[OA-14]`)로 이관함.
  - **Directed TB Sign-off Closure 결과 (`Verification_Plan.xlsx` `direct` Sheet `[DIR-01]~[DIR-03]` 교차 검증 완료):** UVM VIP 제약 및 Xilinx AXI DMA 구조적 한계(`SHA256_FPGA_Verification_Report.md` 3.5절)로 인해 구동되지 않던 `[WV-AXIS-09]`(`TKEEP=4'b0000` Null Beat, `tlast=0/1`) 및 `[WV-AXIS-11]`(패킷 중간 부분 스트로브 포함 27종 비정상 `(TLAST, TKEEP)` 전 조합)은 전용 정적 테스트벤치(`dv/static_tb/tb_sha256_tkeep.sv`)에서 31/31 케이스 전수 통과 및 White-box SVA 무결성 확인을 통해 최종 Sign-off 클로저(Closure)를 달성함.
- **Core (`[WV-CORE-01~04]`):**
  - `core_agent`는 Passive 구조이므로 중복 `start_i` 차단(`[CSR-07]`), 표준/무작위 벡터(`[OA-02, 08]`), 비동기 리셋 구동(`[CORE-14, 16]`)은 상위 Wrapper 테스트 및 FPGA 펌웨어로 이관하여 통합 검증함.
  - **FPGA Sign-off Closure 결과 (`Verification_Plan.xlsx` `direct` Sheet `[FPGA-04, 05]` & `SHA256_FPGA_Verification_Report.md` 교차 검증 완료):** FPGA로 이관된 `[WV-CORE-01]`(`ctrl_ignore`, Busy 중 제어/상태 레지스터 쓰기 차단)은 베어메탈 Atomicity Negative Test(`[FPGA-05]`)에서 `STATUS.ERR_PRT = 1`(`0x00000005`) 및 Data Abort 차단으로 검증되었으며, `[WV-CORE-02]`(`dp_fips`) 및 `[WV-CORE-03]`(`dp_rand`)은 SD 카드 기반 NIST CAVP Byte-Oriented 테스트 스위트(`[FPGA-04]`, `SHA256ShortMsg.rsp` 원본 65개 중 `Len=0` 제외 64개 유효 스트림 벡터 및 `SHA256LongMsg.rsp` 64개 벡터, 총 128개 DMA 스트리밍 벡터 + `Len=0` SW 대조) 100% 일치 통과를 통해 최종 Sign-off 클로저(Closure)를 달성함.
- **CSR (`[WV-CSR-01~03]`):**
  - WO/RO 레지스터 접근 시 `DECERR`/`SLVERR`를 반환하는 방화벽 특성상 내장 RAL 시퀀스 오탐 방지를 위해 제외 후 `[CSR-03, 05]`에서 전용 검증.
  - 연산 완료에 따른 `STATUS.DONE` 자동 갱신은 스트림 주입이 선행되는 `[OA-03]`에서 통합 검증.


# 4. RTL Bug Report

## 4.1 RTL Design Bugs Found & Fixed
검증 과정에서 발견하여 수정 완료한 `sha256_axi_wrapper.sv` 코드 내 5건의 RTL 설계 결함 내역입니다.

### [RTL-BUG-01] Soft Reset 시 하위 Core 리셋 도메인 미연결 (Severity: Critical)

- **Location (`sha256_axi_wrapper.sv`):** `core_rst_n` 생성 할당문 및 `u_core` 인스턴스 `.rst_n_i` 포트 연결부
- **Symptom:** 코어 연산 중 `SOFT_RESET` 인가 후 다음 트랜잭션 구동 시 `CTRL.START` 쓰기가 `SLVERR`로 거부되고 AXI4-Stream `s_axis_tready=0` 타임아웃(Hang) 발생.
- **Root Cause:** `ctrl_soft_reset` 인가 시 Wrapper FSM만 `S_IDLE`로 복귀하고 `u_core`는 리셋되지 않는 '좀비 코어(`core_busy=1`)'가 발생하여 `status_busy`(`transaction_active | core_busy`)가 `1`로 고착됨.
- **RTL Fix Applied (`[PATCH]` History):** `assign core_rst_n = rst_n_i & (~ctrl_soft_reset);`를 생성하여 `u_core`의 `.rst_n_i` 포트 및 `CORE_mon_bfm`에 연결함으로써 Soft Reset 시 Wrapper와 Core가 동시 초기화되도록 수정.

---

### [RTL-BUG-02] Busy 상태 중 `CTRL` 레지스터 쓰기 보호 로직 미비 (Severity: High)

- **Location (`sha256_axi_wrapper.sv`):** `always_ff : csr_logic` 블록 내 `CTRL`(`6'h01`) Busy 상태 쓰기 보호 분기
- **Symptom:** 코어 연산 중(`status_busy==1`) `CTRL` 접근 시 원자성(Atomicity) 보호 및 Hang 복구 예외 처리 미비.
- **Root Cause:** Busy 중 `START`, `IRQ_EN`, `EN` 변경 차단 조건과 예외 허용 비트인 `SOFT_RESET`(bit 3) 분리 로직 부재.
- **RTL Fix Applied (`[PATCH]` History):** `if (status_busy)` 내에서 `ctrl_soft_reset <= wdata_reg[3]`은 허용하되, 나머지 비트(`wdata_reg[2:0]`) 변경 시도 시 기존 설정값을 보존하고 `SLVERR` 및 `status_err_flag <= 1'b1`을 반환하도록 수정.

---

### [RTL-BUG-03] `s_axi_awprot` / `s_axi_arprot` 포트 및 방화벽 로직 누락 (Severity: High)

- **Location (`sha256_axi_wrapper.sv`):** 모듈 포트 선언부(`s_axi_aw/arprot`) 및 `csr_logic` / `rdata_logic` 방화벽 분기
- **Symptom:** MAS 4.3.1절에 정의된 Non-secure(`prot[1]==1`) 접근 차단 방화벽 미동작.
- **Root Cause:** 초기 RTL에 `awprot`/`arprot` 입력 포트와 내부 래치(`awprot_reg`, `arprot_reg`)가 누락됨.
- **RTL Fix Applied (`[PATCH]` History):** 포트 및 래치 레지스터(`aw_latch_logic`, `ar_latch_logic`)를 추가하고, `prot[1]==1` 감지 시 쓰기 차단(`SLVERR` 및 `ERR_PRT=1`) 및 읽기 데이터 `32'd0` 마스킹(`SLVERR`) 로직 구현.

---

### [RTL-BUG-04] AXI4-Stream `TKEEP` 프로토콜 위반 방어 로직 부재 (Severity: High)

- **Location (`sha256_axi_wrapper.sv`):** `axis_tkeep_invalid` / `axis_tkeep_err` 검출 논리 및 `fsm_logic`(`S_RCV`) 분기
- **Symptom:** `S_RCV` 중 비연속 Sparse `TKEEP` 또는 패킷 중간 Partial `TKEEP`(`!tlast && tkeep!=4'b1111`) 주입 시 데이터 정렬 붕괴 및 `byte_cnt == 64` 검사 누락으로 인한 버퍼 오버플로우/데드락 위험 존재.
- **Root Cause:** 입력 `s_axis_tkeep` 패턴의 유효성을 검사하는 하드웨어 방어 로직 부재 및 불필요한 `if (s_axis_tkeep[0])` 분기 존재.
- **RTL Fix Applied (`[PATCH]` History):** `axis_tkeep_invalid` 및 `axis_tkeep_err` 검출 논리를 추가하여 위반 감지 시 `status_err_flag <= 1'b1`(`STATUS.ERR_PRT=1`) 설정, 내부 버퍼 `0x00` 소거 및 `S_IDLE` 즉시 복귀를 수행하도록 수정 (Code Coverage 미달성 분기 동시 해소).

---

### [RTL-BUG-05] `CTRL` 레지스터(`6'h01`) Read 비트맵 순서 오류 (Severity: High)

- **Location (`sha256_axi_wrapper.sv`):** `always_ff : rdata_logic` 블록 내 `CTRL`(`6'h01`) Read 데이터 조합문
- **Symptom:** `uvm_reg_bit_bash_seq` 수행 시 `CTRL` 레지스터 Read/Write 값 불일치(Mismatch) 발생.
- **Root Cause:** `CTRL` 읽기 할당문에서 `ctrl_soft_reset`, `1'b0(START)`, `ctrl_irq_en`, `ctrl_en` 비트 결합 순서가 뒤바뀌어 있었음.
- **RTL Fix Applied (`[PATCH]` History):** `6'h01: s_axi_rdata <= {28'd0, ctrl_soft_reset, 1'b0, ctrl_irq_en, ctrl_en};`으로 수정하여 MAS 4.2.2절 비트맵과 일치시킴.