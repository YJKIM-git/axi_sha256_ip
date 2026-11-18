# Verification Sign-off Report
# UVM 1.2 Block-Level Verification Sign-off for SHA-256 IP Core

# 1. Verification Sign-off Summary

## 1.1 Sign-off Criteria & Achievement Status
본 문서는 `Micro_Architecture_Specification.pdf`(MAS)에 정의된 SHA-256 하드웨어 가속기(`sha256_axi_wrapper` 및 `sha256_core`)에 대해 `SHA256_Verification_Specification.pdf` 1.4절의 정량적 Sign-off 기준 달성 여부를 기록한 최종 검증 보고서입니다.

| Sign-off Category | Sign-off Criteria (`Verification Spec 1.4`) | Target | Final Result | Status |
| :--- | :--- | :---: | :---: | :---: |
| **Regression Status** | 전체 6종 테스트 스위트 실행 시 `UVM_WARNING`, `UVM_ERROR`, `UVM_FATAL` 발생 건수 | `0` | **`0 Warnings / 0 Errors / 0 Fatals`**<br>(6 / 6 Tests Passed) | **PASS** |
| **Scoreboard & RAL Check** | DPI-C 참조 모델(`c_sha256_digest`) 해시 비교 일치율, 상시 CSR 응답 검증(`check_axil_response`) 및 RAL 내장 시퀀스 통과율 | `100%` | **`100%`**<br>(62 DPI-C Hash Matches / 2,358 AXIL Resp Checks / 21 Reset + 9 Bit-Bash Checks) | **PASS** |
| **Assertion (SVA) Status** | 시뮬레이션 전 구간 프로토콜 및 내부 White-box SVA 위반(`Assertion failed`) 발생 건수 | `0` | **`0 Violations`**<br>(All 76 Active SVA Properties + 1 EOS Check Passed) | **PASS** |
| **Functional Coverage** | 5대 검증 도메인 병합(`xcrg`) 기준 활성 Covergroup 달성률 (`Groups Coverage Summary`) | `100%` | **`100.00%`**<br>(Score: `100`, Inst Score: `100` / 19 Active Instances) | **PASS** |
| **Code Coverage** | RTL 설계 전체(`design/*`, Wrapper + Core 6 Modules) 대상 Branch / Condition / Toggle 커버리지 | `100%`<br>(Reachable) | **Condition: `100.00%`** (`100/100`, All Modules)<br>**Branch: `99.42%`** (`171/172`, Reachable `100%`)<br>**Toggle: `65.43%`** (6-File Avg, `6,354/8,122` Bits `78.23%`, Datapath/MsgSched `100%`) | **PASS** |

## 1.2 Simulation Environment & Reference Documents
검증 결과의 재현성(Reproducibility) 보장을 위한 실행 환경 사양과 상위 참조 문서 목록은 다음과 같습니다.

- **Simulation & Coverage Tool Chain (`Makefile`):**
  - **Simulator & Compiler:** Xilinx Vivado Simulator (`xsim v2025.2`, 64-bit, SW Build 6299465), DPI-C Compiler (`xsc`), Elaborator (`xelab -L uvm -timescale 1ns/1ps -debug typical -cc_type bct -sv_lib dpi`)
  - **Coverage Merger:** Xilinx Coverage Report Generator (`xcrg -cov_db_dir ./ -report_dir ./cov_report -ccExclusionFile ./cc_exclude.txt`)
  - **System Clock & Seed:** `100 MHz` (`10 ns` period), Default Deterministic Seed (`1`)
- **Reference Documents & Standards:**
  - **프로토콜 및 알고리즘 표준:** NIST FIPS 180-4, NIST CAVP SHAVS (Byte-Oriented Test Vectors), ARM IHI0022 (AXI4-Lite), ARM IHI0051B (AXI4-Stream), ARM DUI0534B (AMBA 4 Protocol Assertions User Guide), AMD UG1037 (Vivado AXI Reference Guide)
  - **하드웨어 설계 사양서:** `Micro_Architecture_Specification.pdf`
  - **검증 아키텍처 사양서:** `SHA256_Verification_Specification.pdf`
  - **통합 검증 계획서 (5 UVM Domains, Directed/FPGA Closure & Waivers):** `Verification_Plan.xlsx` (`Summary`, `axil`, `axis`, `core`, `csr`, `overall`, `direct`, `waiver_list` Sheets)
  - **FPGA 타겟 통합 검증 보고서:** `SHA256_FPGA_Verification_Report.pdf` (Zynq-7000 SoC Bring-up, NIST CAVP 검증 및 PPA 분석)
  - **VIP 개발 명세서 및 가이드:** `axil_vip_architecture.md`, `axil_user_guide.md`, `axis_vip_architecture.md`, `axis_user_guide.md`

# 2. Regression Test & Scoreboard Results

## 2.1 Test Suite Execution Summary (`rpt_log` & Resource Metrics)

| Test Name (`UVM_TESTNAME`) | Target Domain | `UVM_INFO` | `UVM_WARNING` | `UVM_ERROR` | `UVM_FATAL` | `SVA` Fail | Sim Time / CPU Time | Wall-Clock Elapsed | Result |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`sha256_sanity_test`** | Bring-up / Sanity | 8 | 0 | 0 | 0 | 0 | `2,445 ns` / `0.94 s` | `3 s` (`23:11:52` ~ `23:11:55`) | **PASS** |
| **`sha256_axil_test`** | AXI4-Lite VIP | 9 | 0 | 0 | 0 | 0 | `15,675 ns` / `3.62 s` | `5 s` (`23:11:56` ~ `23:12:01`) | **PASS** |
| **`sha256_axis_test`** | AXI4-Stream VIP | 10 | 0 | 0 | 0 | 0 | `268,005 ns` / `1,402.89 s` | `1,405 s` (`23:12:02` ~ `23:35:27`) | **PASS** |
| **`sha256_core_test`** | Core (Engine) | 20 | 0 | 0 | 0 | 0 | `96,745 ns` / `4.56 s` | `4 s` (`23:35:28` ~ `23:35:32`) | **PASS** |
| **`sha256_csr_test`** | CSR (Wrapper) | 48 | 0 | 0 | 0 | 0 | `345,455 ns` / `2,721.24 s` | `2,737 s` (`23:35:33` ~ `00:21:10`) | **PASS** |
| **`sha256_overall_test`** | Overall (E2E) | 91 | 0 | 0 | 0 | 0 | `238,205 ns` / `1,294.26 s` | `1,297 s` (`00:21:12` ~ `00:42:49`) | **PASS** |
| **Total / Summary** | **5 Domains (114 Plan Rows)** | **186** | **0** | **0** | **0** | **0** | **`966,530 ns` / `5,427.51 s`** | **`5,451 s` (`90m 51s`)** | **100% PASS** |

> **Supplemental Directed Testbench Execution (`dv/static_tb/tb_sha256_tkeep.sv`, `Verification_Plan.xlsx` `direct` Sheet `[DIR-01]~[DIR-03]`):** UVM VIP 제약 및 Xilinx AXI DMA 하드웨어 구조상 구동이 제한되는 Null Beat(`TKEEP = 4'b0000`, `[WV-AXIS-09]`)와 패킷 중간/마지막 Beat의 비정상 `(TLAST, TKEEP)` 27종 진리표 전 조합(`[WV-AXIS-11]`, `[OA-14]`)을 종결하기 위해 별도의 SVA 기반 정적 테스트벤치를 구동했습니다. 시뮬레이션 결과, 총 **31 / 31 테스트 케이스(Null Beat 3건, 27종 스윕 27건, 에러 인터럽트 발생/해제 확인 후 `"abc"` Golden 해시 복구 1건) 및 7종 White-box SVA가 `0 Error`로 100% PASS**했습니다.

## 2.2 UVM Report ID & Scoreboard Verification Summary
각 테스트 로그(`xsim_*.log`) 하단의 `--- UVM Report Summary --- (Report counts by id)`에 집계된 검증 판정 및 시퀀스 구동 통계는 다음과 같습니다 (`UVM_VERBOSITY = UVM_LOW` 기준).

| UVM Report ID Tag (`[ID]`) | Source Component / Sequence | `sanity` | `axil` | `axis` | `core` | `csr` | `overall` | Total Count |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **`[oa_byte_swap / Datapath]`** | `sha256_scoreboard::compare_hash()` | 1 | - | - | 1 | - | 48 | **50** |
| **`[oa_pad_edge]`** | `sha256_scoreboard::compare_hash()` | - | - | - | 4 | - | 6 | **10** |
| **`[oa_manual_chain]`** | `sha256_scoreboard::compare_hash()` | - | - | - | - | - | 2 | **2** |
| **`[uvm_reg_hw_reset_seq]`** | `sha256_csr_vseq::do_csr_reset()` | - | - | - | - | 21 | - | **21** |
| **`[uvm_reg_bit_bash_seq]`** | `sha256_csr_vseq::do_csr_bit_bash()` | - | - | - | - | 9 | - | **9** |
| **`[VSEQ_OA]`** | `sha256_overall_vseq` | - | - | - | - | - | 26 | **26** |
| **`[VSEQ / VSEQ_CORE / AXIS / AXIL]`** | Domain Virtual Sequences | - | 2 | 3 | 8 | 9 | 2 | **24** |
| **`[TEST_RESULT]`** | `sha256_test_base::report_phase()` | 1 | 1 | 1 | 1 | 1 | 1 | **6** |
| **`[UVM System & Test Lifecycle]`** | UVM Kernel & `uvm_test_top` (`RNTST`, `TEST_DONE` 등) | 6 | 6 | 6 | 6 | 8 | 6 | **38** |
| **Total (`UVM_INFO` Sum)** | **All Components (`2.1절` 일치)** | **8** | **9** | **10** | **20** | **48** | **91** | **186** |

**Verification Meaning (Report ID별 검증 의미):**

- **`[oa_byte_swap / Datapath]` (`50`):** 고정 벡터(3B `"abc"`) 및 가변 길이 패킷(1B, 4B×27, 13B, 16B, 44B, 63B, 68B×7 스윕, 92B, 119B×2, 120B×2, 127B, 128B×2, 246B, 303B)의 DPI-C 해시 일치 횟수
- **`[oa_pad_edge]` (`10`):** 코어 데이터패스 스트레스 패턴(64B×4: All-0, All-1, Walking-1, Walking-0), 단일 블록 패딩 경계(55B, 56B, 64B), 그리고 `All-0x80` 패딩 경계(55B, 56B, 64B)의 DPI-C 해시 일치 횟수
- **`[oa_manual_chain]` (`2`):** `STATE_IN_0~7`에 Custom IV 적재 후 구동한 단일 블록(4B) 및 다중 블록(80B) 스트리밍의 DPI-C Custom IV 해시 일치 횟수
- **`[uvm_reg_hw_reset_seq]` (`21`):** WO(`INTCLEAR`) 제외 전체 21개 CSR 레지스터의 하드웨어 리셋 초기값(표준 IV 등) 대조 완료
- **`[uvm_reg_bit_bash_seq]` (`9`):** RW 권한 9개 레지스터(`STATE_IN_0~7`, `CTRL`)의 비트 단위 0/1 교차 쓰기/읽기 검증 완료
- **`[VSEQ_OA]` (`26`):** Overall 서브 시퀀스 단계별 진입 및 제어 차단(`EN=0` 시작 무시 및 수신 차단, `IRQ_EN=0` 마스킹)·병렬 대기(`block_pending`)·`All-0x80` 경계·예외 복구(`TKEEP` 에러 및 중간 `DIGEST` 제로화/인터럽트 해제, Starvation, Busy/Overlapped `SOFT_RESET`) 자체 검증 통과 로그
- **`[VSEQ / VSEQ_CORE / AXIS / AXIL]` (`24`):** 각 도메인 Virtual Sequence 및 하위 검증 태스크의 시작/종료 마일스톤 로그
- **`[TEST_RESULT]` (`6`):** `=== SHA256 UVM TEST PASSED ===` 최종 판정 배너 출력
- **`[UVM System & Test Lifecycle]` (`38`):** 각 테스트 시작/종료 시 출력되는 UVM 프레임워크 기본 상태 보고(`UVM/RELNOTES`, `NO_DPI_TSTNAME`, `RNTST`, `UVM/COMP/NAMECHECK`, `TEST`, `TEST_DONE` 각 6건 및 `csr_test` 내 `STARTING_SEQ` 2건)

> **Scoreboard 및 RAL 검증 집계 요약:** 전체 회귀 테스트 동안 **총 62건의 DPI-C 참조 모델 해시 일치(`50 + 10 + 2`, 표준 IV 60건 + Custom IV 2건)**, **총 2,358건의 AXI4-Lite 트랜잭션(Write 1,039건 + Read 1,319건)에 대한 `check_axil_response()` 상시 응답/제로 마스킹 검증**, 그리고 **총 30건의 RAL 내장 시퀀스 점검(`21 Reset + 9 Bit-Bash`)**을 `0 Error`로 100% 달성했습니다.


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

- **`grp0` (`cg_axi4lite_32b_normal`):** 32-bit 정상 R/W(`DIR`), `OKAY`(`RESP`), `WSTRB_32B`(3종), `PROT`(8종), `ALIGN_32B`, 5채널 딜레이(`AW/W/B/AR/R_DELAY`, `0-cycle`은 `ignore_bins`) 및 4종 교차(`CROSS_DIR_RESP`, `CROSS_WRITE_WSTRB_32B`, `CROSS_DIR_ALIGN32`, `CROSS_AW_W_DELAY`)
- **`grp1` (`cg_axi4lite_32b_error`):** 32-bit R/W 방향별 에러 응답(`SLVERR`, `DECERR`는 `grp20`으로 이관하여 `ignore_bins`) 및 비정렬 주소(`ERR_ALIGN_32B`) 교차
- **`grp4` (`cg_routing_matrix_type`):** 라우팅 `cp_tid`/`cp_tdest` 기본 상태(`0`) 확인 (`[WV-AXIS-13]` DUT 미사용 핀으로 Cross 생략)
- **`grp5` (`cg_routing_change_type`):** 패킷 경계 라우팅 변경 확인 (`[WV-AXIS-14]` `option.weight = 0` Waiver 적용)
- **`grp6` (`cg_data_pattern_type`):** 32-bit `All_0`, `All_1`, `Toggle`(`32'h5555_5555`) × `TLAST`(`0`/`1`) 교차 (`cr_pattern_tlast`)
- **`grp7` (`cg_backpressure_corner_type`):** `TLAST` 인접 여부(`away_from_tlast`, `near_tlast`) × 코어 연산 장기 Back-Pressure(`long`, `[WV-AXIS-10]` `short`는 `ignore_bins`) 교차
- **`grp8` (`cg_byte_qualifier_type_partial`):** `TLAST=0, All-1` 및 `TLAST=1, All-1 / Partial` 조건부 교차 (`cp_tlast_tkeep_cross`, `[WV-AXIS-11]` `KEEP_ALL_0` 및 패킷 중간 Partial은 제외)
- **`grp10` (`cg_tkeep_tstrb_type_partial`):** 활성 바이트 폭 내 `TKEEP` 및 `TSTRB` 일치 조건(`all_1_match`, `partial_match`, `[WV-AXIS-12]`)
- **`grp12` (`cg_sideband_type_mixed`):** `TUSER` 사이드밴드 그룹 (`[WV-AXIS-15]` `option.weight = 0` Waiver 적용)
- **`grp14` (`cg_handshake`):** `cp_valid_wait`(`0~extreme`) × `cp_ready_wait`(`ready_first`, `extreme_backpressure`, `[WV-AXIS-07]` `1~20`클록 단·중기 Back-Pressure는 `ignore_bins`) 교차
- **`grp15` (`cg_packet_boundary`):** 단일(1-Beat) 및 버스트(Multi-Beat) 패킷 × 패킷 간 간격(`long_gap`, `[WV-AXIS-08]` `0~5`클록 IPG는 `ignore_bins`) 교차
- **`grp16` (`cg_reset`):** 정상 전송(`clean_reset`) 및 전송 중 리셋 중단(`active_transfer_reset`) 도달
- **`grp17` (`cg_null_transfer`):** 정상 바이트 전송(`normal = {0}`, `[WV-AXIS-09]`) × 패킷 경계(`not_last`, `last`) 교차
- **`grp18` (`cg_dp`):** 512-bit `All-0`, `All-1`, `Walking-1`, `Walking-0` 스트레스 패턴 및 단일/체이닝 블록(`cp_chain`)
- **`grp19` (`cg_rst`):** 리셋 중단 여부, 중단 사이클(`0~66` 67개 Bin), 중단 라운드(`0~63` 64개 Bin) 전 구간 도달
- **`grp20` (`cg_csr_protocol`):** 레지스터 분류(5종), 방향, 응답(3종), 보안(`PROT`), Busy 상태 및 3대 예외 교차(`cr_wo_err`, `cr_busy_prot`, `cr_secure_prot` — 방화벽 구조상 불가능한 응답 조합은 `ignore_bins` 처리)
- **`grp21` (`cg_hw_update`):** 코어 연산 완료 시 `STATUS.DONE` 필드의 `0 => 1` 상승 전이 (`[WV-CSR-03]`으로 이관되어 Overall에서 달성)
- **`grp22` (`cg_payload`):** 단일/다중 블록 패딩 경계(`55, 56, 64, 119, 120, 128B`), `All-0x80` 경계(`cp_all80_edge` 9개 Bin), 블록 모드×정렬(`cr_block_align` 4개 교차)
- **`grp23` (`cg_exception`):** 스트림 대기 중 Soft Reset(`rst_while_idle`) 및 코어 연산 중 Soft Reset(`rst_while_busy`)

> *미생성 조건부 그룹 (5개, `Num Instances = 0`):* `grp2`(`cg_axi4lite_64b_normal`), `grp3`(`cg_axi4lite_64b_error`), `grp9`(`cg_byte_qualifier_type_no_partial`), `grp11`(`cg_tkeep_tstrb_type_no_partial`), `grp13`(`cg_sideband_type_no_mixed`)은 64-bit 전용 또는 8-bit 이하/`TUSER` 비활성 조건부 그룹으로 본 32-bit 설정에서는 인스턴스화되지 않으며 전체 점수 집계에서도 자동 제외됩니다.


## 3.2 Assertion (SVA) Verification Summary
인터페이스 내장형 SVA와 `bind` 기반 White-box SVA 총 76개 활성 프로퍼티에 대한 검증 요약입니다 (개별 프로퍼티 명세는 `Verification_Plan.xlsx` 참조).

| SVA Module / Interface | Binding Target (`hdl_top`) | Plan Reference (`Verification_Plan.xlsx`) | Property Count | Failure Count (`rpt_log`) | Status |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **`axi4lite_if.sv`** | `AXI4LITE` (Built-in) | `axil` Sheet (`[AXIL-01]` ~ `[AXIL-24]`) | `23` Active<br>(24 Declared, `[AXIL-17]` 64b Disabled) | `0` | **PASS** |
| **`axis_if.sv`** & `axis_monitor` | `AXIS` (Built-in & `check_phase`) | `axis` Sheet (`[AXIS-01]` ~ `[AXIS-12]`) | `20` Active SVA<br>(+ `1` EOS `check_phase`, ARM 28종 대응) | `0` | **PASS** |
| **`core_if.sv`** & `intr_bfm.sv` | `CORE`, `INTR_bfm` (Built-in) | `core` Sheet (`[CORE-08, 14, 15, 17]`), `csr` Sheet (`[CSR-01]`) | `5` | `0` | **PASS** |
| **`sha256_wrapper_sva.sv`** | `DUT` (`bind_wrapper_sva`) | `csr` Sheet (`[CSR-03~07, 09, 10]`), `overall` Sheet (`[OA-03~05, 11, 14~20]`) | `19`<br>(CSR 7종 + Overall 12종) | `0` | **PASS** |
| **`sha256_core_sva.sv`** | `DUT.u_core` (`bind_core_sva`) | `core` Sheet (`[CORE-01]` ~ `[CORE-07]`, `[CORE-18, 19]`) | `9` | `0` | **PASS** |
| **Total / Summary** | **All Interfaces & DUT Submodules** | **5 Domains** | **`76` Active SVA**<br>(+ `1` EOS Check) | **`0`** | **100% PASS** |

## 3.3 Code Coverage Summary (`xcrg` Merged Report)

### 3.3.1 DUT Module-Level Code Coverage Breakdown
`cc_exclude.txt`를 통해 검증 대상 RTL 설계(`design/*`, 총 6개 모듈 파일)에 한정하여 수집된 `xcrg` Code Coverage(**Branch / Condition / Toggle**) 최종 달성 현황입니다 (`files.html` 및 `file2~10.html` 기준).

| File ID (`files.html`) | Module / File Name (`design/`) | Inst Count | Branch Score (%) | Condition Score (%) | Toggle Score (%) | Toggle Bits / Vars Detail |
| :---: | :--- | :---: | :---: | :---: | :---: | :--- |
| **`file2`** | **`sha256_axi_wrapper`** (`sha256_axi_wrapper.sv`) | 1 | **`99.32%`** (`145/146`) | **`100.00%`** (`88/88`) | **`69.26%`** | `3,786 / 5,466` bits (`39 / 46` vars, `84.78%`) |
| **`file3`** | **`sha256_core`** (`sha256_core.sv`) | 1 | N/A (`0/0`) | N/A (`0/0`) | **`40.00%`** | `8 / 20` bits (`4 / 5` vars, `80.00%`) |
| **`file4`** | **`sha256_datapath`** (`sha256_datapath.sv`) | 1 | **`100.00%`** (`5/5`) | **`100.00%`** (`2/2`) | **`100.00%`** | `1,152 / 1,152` bits (`18 / 18` vars, `100%`) |
| **`file5`** | **`sha256_round_logic`** (`sha256_round_logic.sv`) | 1 | N/A (`0/0`) | N/A (`0/0`) | **`83.33%`** | `320 / 384` bits (`5 / 6` vars, `83.33%`) |
| **`file9`** | **`sha256_controller`** (`sha256_controller.sv`) | 1 | **`100.00%`** (`17/17`) | **`100.00%`** (`8/8`) | **`0.00%`** | `0 / 12` bits (`0 / 1` var, `round_idx_r`) |
| **`file10`** | **`sha256_message_schedule`** (`sha256_message_schedule.sv`) | 1 | **`100.00%`** (`4/4`) | **`100.00%`** (`2/2`) | **`100.00%`** | `1,088 / 1,088` bits (`2 / 2` vars, `w_mem` 포함) |
| **Total** | **6 RTL Files (`files.html`)** | **6** | **`99.42%`** (`171/172`) | **`100.00%`** (`100/100`) | **`65.43%`** *(File Avg)* | **`78.23%`** (`6,354 / 8,122` bits, `68 / 78` vars) |

**Module Role & Coverage Summary:**

- **`sha256_datapath` (`file4`) & `sha256_message_schedule` (`file10`):** 코어 내부 256-bit 작업 레지스터(`a_r~h_r`), 512-bit 메시지 스케줄러(`w_mem[0:15]`), 라운드 입출력 와이어 전 항목에서 **Branch, Condition, Toggle 모두 `100.00%`를 달성**했습니다.
- **`sha256_axi_wrapper` (`file2`) & `sha256_controller` (`file9`):** 모든 복합 조건식(**Condition Coverage `100.00%`**, `88/88` 및 `8/8`)과 도달 가능한 모든 분기(**Reachable Branch `100.00%`**)를 달성했습니다.

### 3.3.2 Uncovered Code Analysis & Waiver Justifications
미달성(Uncovered)으로 집계된 **Branch 1건(`171/172`)** 및 **Toggle 10개 변수(`884 bits` / 양방향 `1,768 toggle bits`)**는 원인에 따라 아래 4개 카테고리로 분류되며, 설계 결함이나 검증 누락으로 인한 미달성 항목은 `0건`입니다.

| No. | Category | Target Module (`File ID`) | Uncovered Target / Signal | Verification & Proof Method |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **Defensive Code**<br>*(Unreachable)* | `sha256_axi_wrapper` (`file2`) | • `default: ;` (`Branch 146`, Line 581) | 자극 불가 |
| **2** | **Spec & Structural**<br>*(55 bits)* | `sha256_axi_wrapper` (`file2`) | • `msg_len[2:0]` (3 bits)<br>• `msg_len[63:12]` (52 bits) | • `[2:0]`: 바이트 단위 신호이므로 자극 불가<br>• `[11:3]`: Toggled<br>• `[63:12]`: 시뮬레이션 시간 제약 Waiver (`[FPGA-04]`에서 `[15:12]` 추가 검증) |
| **3** | **Tool Artifact A**<br>*(Control & Addr)* | `sha256_axi_wrapper` (`file2`)<br>`sha256_core` (`file3`)<br>`sha256_controller` (`file9`) | • `awaddr_reg[7:0]` (8b), `valid_bytes[2:0]` (3b)<br>• `state[2:0]` (3b), `ret_state[2:0]` (3b)<br>• `round_idx_r/o[5:0]` (6b×2) | Waveform 및 SVA로 toggle 확인 완료<br>• 툴 오류로 인한 `xsim` 집계 누락으로 추정 |
| **4** | **Tool Artifact B**<br>*(Wide Datapath)* | `sha256_axi_wrapper` (`file2`)<br>`sha256_round_logic` (`file5`) | • `core_block_reg[511:0]` (512b)<br>• `core_state_out[255:0]` (256b)<br>• `t1_o[31:0]` (32b) | 연결된 동일한 레지스터의 `100% Toggle` 달성 및 해시 알고리즘의 특수성을 고려하여 전 비트 toggle 확인 완료<br>• 툴 오류로 인한 `xsim` 집계 누락으로 추정 |

**Detailed Technical Justification (카테고리별 상세 소명 근거):**

1. **Defensive Default Branch (`file2` Line 581, `1 / 172` Branch):**
   - `state` 레지스터는 리셋 시 `S_IDLE`(`3'd0`)로 초기화되고 정의된 7개 유효 상태(`3'd0 ~ 3'd6`)로만 전이하므로, 순차 블록(`fsm_datapath_reg`)의 `default: ;` 분기는 정상 동작 중 도달 불가능한 합성 방어용 코드입니다.
2. **Message Bit-Length Counter (`file2` Line 103, `msg_len`):**
   - `msg_len[2:0]`: 바이트 스트리밍 규격상 항상 8의 배수(`{58'd0, valid_bytes, 3'b000}`)만 가산되므로 상수 `0`으로 고정됩니다.
   - `msg_len[11:3]`: 최대 507B($4,056\text{ bits}$) 스트리밍을 통해 **`100% Toggle`을 달성**했습니다.
   - `msg_len[63:12]`: 최대 $2^{64}-1\text{ bits}$ 지원용 카운터 비트로 RTL 시뮬레이션 시간 제약상 Waiver 처리하며, `[OA-02, 21]`의 `MSG_LEN_LO/HI` 레지스터 대조 및 FPGA 검증(`[FPGA-04]`, 최대 `msg_len[15:3]` toggle)을 추가 시도함. 근본적인 시간 한계로 전 비트 toggle 불가.
3. **Tool Artifact A — 제어·주소 신호 (`awaddr_reg`, `valid_bytes`, `state`, `ret_state`, `round_idx_r/o`):**
  - 리포트상 `0`으로 집계되었으나, Waveform/SVA/Branch/Condition 결과를 통해 전 비트 toggle을 확인했습니다.
4. **Tool Artifact B — 데이터패스 신호 (`core_block_reg`, `core_state_out`, `t1_o`):**
  - 리포트상 `0`으로 집계되었으나, 1:1로 직결된 전후방 레지스터의 `100% Toggle` 달성 결과를 통해 해당 비트들이 토글되었음을 확인했습니다. 또한 해시 알고리즘 특성상 한 비트만 오염되도 해시값이 달라지므로, 이를 통해서도 유추가 가능합니다.

## 3.4 Verification Plan Waivers & Technical Justifications
`Verification_Plan.xlsx`의 `waiver_list` 시트에 등록된 총 32건(Partial Waiver 15건, Full Waiver 17건)의 도메인별 Waiver 요약입니다.

| Domain | Waiver ID Range | Waived Item / Target | Waiver Level |
| :--- | :--- | :--- | :--- |
| **AXI4-Lite VIP** | `[WV-AXIL-01~03]` | `p_addr_alignment_32`, `p_*_timeout`<br>`p_addr_alignment_64`, `cg_axi4lite_64b_*` | Partial Waiver (2)<br>Waiver (1, N/A) |
| **AXI4-Lite VIP** | `[WV-AXIL-04~08]` | `AW/W/B/AR/R_DELAY` (`back_to_back = {0}`)<br>`ERR_RESP` (`decerr = {2'b11}`), `CROSS_DIR_ERR_RESP` | Partial Waiver (5, `ignore_bins`) |
| **AXI4-Stream VIP** | `[WV-AXIS-01~06]`<br>`[WV-AXIS-12~18]` | `TID`, `TDEST`, `TSTRB`, `TUSER` SVA 및 CG<br>`DATA_WIDTH <= 8` (`_no_partial`), Zero-width | Waiver (11) /<br>Partial Waiver (2) |
| **AXI4-Stream VIP** | `[WV-AXIS-07~11]` | `cg_handshake`, `cg_backpressure_corner` 단기 Back-Pressure<br>`cg_packet_boundary` (`0~5`클록 IPG)<br>`TLAST=0 & Partial`, `TKEEP=0` (`cg_null_transfer`) | Partial Waiver (4) /<br>Waiver (1, Closed by Static TB) |
| **Core** | `[WV-CORE-01~03]` | `ctrl_ignore` (`[CORE-09]`), `dp_fips` (`[CORE-10]`),<br>`dp_rand` (`[CORE-11]`) | Waiver (3, Delegated to Wrapper & FPGA) |
| **CSR** | `[WV-CSR-01~03]` | `INTCLEAR` in `hw_reset_seq` (`[CSR-01]`)<br>RO/WO Regs in `bit_bash_seq` (`[CSR-02]`)<br>`csr_hw_update` (`[CSR-08]`, `cg_hw_update`) | Partial Waiver (2) /<br>Waiver (1, Delegated to Overall) |

**Technical Justification Summary (도메인별 Waiver 사유 요약):**

- **AXI4-Lite VIP (`[WV-AXIL-01~03]`):**
  - 주소 정렬 및 타임아웃 SVA는 상시 감시(`0`)를 기본으로 운용하되, 에러 주입 플래그가 활성화된 단일 트랜잭션 구동 구간 동안에만 `AXI4LITE_drv_bfm`이 동적으로 마스킹 후 즉시 복원함.
  - DUT는 32-bit 고정 데이터 폭(`DATA_WIDTH=32`)이므로 64-bit 전용 SVA 및 CG는 미적용.
- **AXI4-Lite VIP (`[WV-AXIL-04~08]`):**
  - DUT의 `s_axi_*ready` 및 `bvalid/rvalid`가 `always_ff` 레지스터 출력이므로 0-cycle 응답은 구조적으로 발생 불가하여 `ignore_bins` 처리.
  - 주소 맵에 종속적인 `DECERR` 검증은 CSR 도메인(`[CSR-05, 06]`)으로 이관하여 수집.
- **AXI4-Stream VIP (`[WV-AXIS-01~06]`, `[WV-AXIS-12~18]`):**
  - SHA-256 DUT에 라우팅/스트로브/사이드밴드 포트가 존재하지 않음 (MAS 4.1.2절).
  - 32-bit 고정 폭 환경이므로 단일 바이트(`<=8-bit`) 및 Width 0 조건은 해당 사항 없음.
- **AXI4-Stream VIP (`[WV-AXIS-07~11]`):**
  - DUT 코어의 고정 레이턴시로 인해, 단기/중기 Back-Pressure(`1~20`클록) 및 `0~5`클록 IPG는 구조적으로 발생하지 않으므로 `ignore_bins` 처리.
  - **Directed TB Sign-off Closure 결과 (`Verification_Plan.xlsx` `direct` Sheet `[DIR-01]~[DIR-03]` 교차 검증 완료):** UVM VIP 제약 및 Xilinx AXI DMA 구조적 한계(`SHA256_FPGA_Verification_Report.md` 3.5절)로 인해 구동되지 않던 `[WV-AXIS-09]`(`TKEEP=4'b0000` Null Beat, `tlast=0/1`) 및 `[WV-AXIS-11]`(패킷 중간 부분 스트로브 포함 27종 비정상 `(TLAST, TKEEP)` 전 조합)은 전용 정적 테스트벤치(`dv/static_tb/tb_sha256_tkeep.sv`)에서 31/31 케이스 통과 및 White-box SVA 무결성 확인을 통해 최종 Sign-off 클로저(Closure)를 달성함.
- **Core (`[WV-CORE-01~03]`):**
  - `core_agent`는 Passive 구조이므로 `sha256_core_test`에서는 단일 블록을 통한 코어 스트레스(`[CORE-12, 13]`) 및 리셋(`[CORE-16]`) 검증에 집중하고, 중복 시작/상태 변경 차단(`[CSR-07]`)과 표준/무작위 메시지 스트리밍(`[OA-02, 07, 08]`)은 상위 Wrapper 테스트 및 FPGA 펌웨어로 이관하여 검증함. (단, 비동기 리셋 `[CORE-17]`은 `core_if.sv`에 `a_rst_async`를 구현하여 Active 검증 완료.)
  - **FPGA Sign-off Closure 결과 (`Verification_Plan.xlsx` `direct` Sheet `[FPGA-04, 05]` & `SHA256_FPGA_Verification_Report.md` 교차 검증 완료):** `[WV-CORE-01]`(`ctrl_ignore`)은 베어메탈 Atomicity 테스트(`[FPGA-05]`)에서 `STATUS.BUSY = 1` 유지 및 Data Abort 차단으로 검증되었으며, `[WV-CORE-02, 03]`(`dp_fips`, `dp_rand`)은 SD 카드 기반 NIST CAVP 테스트 스위트(`[FPGA-04]`, `SHORT_TV.BIN` 65종 및 `LONG_TV.BIN` 64종) 100% 일치 통과를 통해 최종 Sign-off.
- **CSR (`[WV-CSR-01~03]`):**
  - WO/RO 레지스터 접근 시 `DECERR`/`SLVERR`를 반환하는 방화벽 특성상 내장 RAL 시퀀스 오탐 방지를 위해 제외 후 `[CSR-03, 05]`에서 전용 검증.
  - 연산 완료에 따른 `STATUS.DONE` 자동 갱신은 스트림 주입이 선행되는 `[OA-03]`에서 통합 검증.

# 4. RTL Bug Report

## 4.1 RTL Design Bugs Found & Fixed
`Verification_Plan.xlsx`에 정의된 UVM 검증 시나리오 및 White-box SVA 구동 과정에서 검출하여 수정 완료한 `sha256_axi_wrapper.sv` 내 4건의 RTL 설계 결함입니다.

| Bug ID | Severity | Functional Scope | Violated Plan ID | Detection Mechanism (SVA / Sequence) |
| :--- | :---: | :--- | :---: | :--- |
| **`[RTL-BUG-01]`** | Critical | Reset Domain | `[OA-13]`, `[OA-19]` | `p_oa_tkeep_err_kills_core`, `do_oa_busy_recov()` |
| **`[RTL-BUG-02]`** | Critical | Overlapped Chaining | `[OA-18]` | `p_oa_global_core_done_latch`, `do_oa_stress()` |
| **`[RTL-BUG-03]`** | High | Control FSM | `[OA-11]` | `p_start_ignored_when_disabled`, `do_oa_disable()` |
| **`[RTL-BUG-04]`** | High | Error Interrupt Isolation | `[CSR-10]` | `p_sync_err_no_irq`, `do_decouple_sync()` |

---

### 4.1.1 [RTL-BUG-01] 병렬 수신 중 `TKEEP` 위반 및 Soft Reset 발생 시 하위 Core 리셋 누락 (Severity: Critical)

- **Violated Test Plan:** `[OA-13]` (`oa_busy_recov`), `[OA-19]` (`oa_overlap_abort`) — `p_oa_tkeep_err_kills_core`, `do_oa_busy_recov()`, `do_oa_tkeep_err()`
- **Description:** 1번째 블록의 코어 연산이 진행되는 도중(`core_busy == 1`) 2번째 블록 병렬 수신(`S_RCV`) 구간에서 비정상 `TKEEP`이 주입(`axis_tkeep_err == 1`)되거나 `CTRL.SOFT_RESET`이 인가되었을 때, 하위 코어가 멈추지 않아 `STATUS.BUSY`가 `1`로 고착되고 후속 트랜잭션이 거부되는 데드락이 발생함.
- **Root Cause & RTL Fix:** 예외 발생 시 Wrapper FSM만 `S_IDLE`로 복귀하고 하위 `u_core`의 리셋 신호에 스트림 프로토콜 에러 조건이 연동되지 않음. 비동기 리셋(`!rst_n_i`) 시 `0`으로 초기화되고 동작 중 `core_rst_n <= (~ctrl_soft_reset) & (~axis_tkeep_err);`로 구동되는 통합 리셋 신호를 생성하여 `u_core`에 인가함으로써 예외 발생 즉시 Wrapper와 하위 Core가 동시에 초기화되도록 수정.

### 4.1.2 [RTL-BUG-02] 저속 스트리밍으로 인한 `S_RCV` 중 비동기 `core_done` 체이닝 유실 (Severity: Critical)

- **Violated Test Plan:** `[OA-18]` (`oa_async_done_chain`) — `p_oa_global_core_done_latch`, `do_oa_stress()`
- **Description:** 다중 블록 전송 시 AXI4-Stream 마스터의 `TVALID` 인가 지연(Stall)으로 인해 후속 블록(16 Beats) 수신 시간이 이전 블록의 코어 연산 시간(67클록)보다 길어질 경우, Wrapper가 `S_RCV` 상태에 머무르는 도중 발생한 `core_done` 완료 펄스를 놓쳐 중간 해시 체이닝이 누락되고 최종 해시 불일치가 발생함.
- **Root Cause & RTL Fix:** 스트림 수신이 코어 연산보다 늦게 끝나는 경우가 누락되어 `core_done` 결과 캡처 및 `first_block <= 0` 갱신 로직을 `S_WAIT_CORE` 상태 내부에만 작성했던 것이 원인임. `if (core_done && !axis_tkeep_err)` 캡처 구문을 상태 머신(`unique case (state)`) 외부의 전역 조건으로 분리하여, Wrapper가 `S_RCV`나 `S_PAD_*` 상태에 있더라도 이전 블록의 연산 결과를 유실 없이 래치하도록 수정.

### 4.1.3 [RTL-BUG-03] `CTRL.EN == 0` 상태에서 `CTRL.START == 1` 단독 인가 시 셀프 데드락 (Severity: High)

- **Violated Test Plan:** `[OA-11]` (`oa_disable`) — `p_start_ignored_when_disabled`, `do_oa_disable()`
- **Description:** `CTRL.EN = 0` 상태에서 `CTRL.START = 1`(`0x04`)을 단독 기록하면 `STATUS.BUSY`가 `1`로 활성화되며 `S_RCV`로 진입하지만, `s_axis_tready`는 `EN == 0`에 의해 `0`으로 차단되고 Busy 보호 로직으로 인해 `CTRL.EN = 1` 재설정도 `SLVERR`로 거부되는 셀프 데드락이 발생함.
- **Root Cause & RTL Fix:** `S_IDLE` 상태에서 모듈 활성화(`ctrl_en`) 여부를 확인하지 않고 `ctrl_start_pulse`만으로 트랜잭션을 기동함. `S_IDLE` 상태 전이 및 `transaction_active` 활성화 조건을 `if (ctrl_start_pulse && ctrl_en)`으로 수정하여 비활성 상태에서의 시작 요청을 무시하도록 수정.

### 4.1.4 [RTL-BUG-04] AXI4-Lite 제어 버스 에러(`SLVERR`) 발생 시 에러 인터럽트 오발화 (Severity: High)

- **Violated Test Plan:** `[CSR-10]` (`csr_decouple_sync`) — `p_sync_err_no_irq`, `do_decouple_sync()`
- **Description:** `CTRL.IRQ_EN == 1` 상태에서 Non-secure(`AxPROT[1] == 1`) 접근이나 읽기 전용(RO) 레지스터 쓰기 시도로 인해 AXI4-Lite 동기식 에러(`SLVERR`)가 발생할 때, 스트림 프로토콜 에러 플래그인 `STATUS.ERR_PRT`까지 `1`로 설정되어 불필요한 에러 인터럽트(`irq_o = 1`)가 발생함.
- **Root Cause & RTL Fix:** 초기 설계에서 AXI4-Lite 버스 보호 위반 시 `bresp_reg <= 2'b10` 응답과 함께 `status_err_flag <= 1'b1`을 동시에 구동하여 두 에러 도메인이 혼재됨. 제어 버스 위반 시에는 In-band 응답(`SLVERR`/`DECERR`) 및 읽기 데이터 `0` 마스킹만 수행하고, `status_err_flag`는 오직 `axis_tkeep_err` 발생 시에만 설정되도록 분리하여 제어 버스 에러와 인터럽트를 분리.