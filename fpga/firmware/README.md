# Zybo Z7-20 SHA-256 Verification Firmware Technical Reference

## 1. System Overview & Hardware Environment
본 펌웨어는 Xilinx Zynq-7000 SoC (Zybo Z7-20) 베어메탈(Standalone) 환경에서 NIST FIPS 180-4 규격 SHA-256 하드웨어 가속기(`sha256_axi_wrapper_0`)의 기능, 보안 예외 처리, 그리고 시스템 성능을 검증하기 위해 설계되었습니다. 전체 검증 결과 및 PPA 분석은 `SHA256_FPGA_Verification_Report.md` 및 `Verification_Plan.xlsx`(`direct` 시트 `[FPGA-01]~[FPGA-09]`)에 수록되어 있습니다.

| 구성 요소 | 하드웨어 사양 및 매핑 정보 | 비고 |
| :--- | :--- | :--- |
| **APU (PS7)** | Dual ARM Cortex-A9 @ `666.67 MHz` | Global Timer @ `333.33 MHz` (APU/2) |
| **PL Fabric Clock** | `FCLK_CLK0` @ `100.00 MHz` | SHA-256 IP, AXI DMA, Interconnect 동기화 |
| **SHA-256 IP CSR** | Base Address: `0x40000000` (Range `4 KB`) | `M_AXI_GP0` 연결 (AXI4-Lite Slave) |
| **AXI DMA** | Base Address: `0x40400000` (Range `64 KB`) | Direct Register Mode, MM2S Only (`S_AXI_HP0` 64-bit) |
| **Interrupt Routing** | `xlconcat_0` $\rightarrow$ `IRQ_F2P[1:0]` | `DMA_MM2S_IRQ_ID = 61`, `SHA256_DONE_IRQ_ID = 62` |

---

## 2. Directory & File Structure

```text

scripts/
└── preprocess_rsp.py      # NIST CAVP .rsp 텍스트 파일을 이진 포맷(.BIN)으로 변환하는 PC 스크립트
firmware/
└── src/
    ├── sha256_hal.h / .c      # SHA-256 IP CSR 레지스터 추상화 및 하드웨어 제어 HAL 드라이버
    ├── dma_utils.h / .c       # AXI DMA MM2S 초기화, D-Cache Flush 및 SimpleTransfer 래퍼
    ├── sd_parser.h / .c       # FatFs(ff.h) 기반 SD 카드 마운트 및 전처리 이진 벡터(.BIN) 로더
    ├── sha256_ref_model.h / .c# PS 영역 성능 비교 및 Golden 해시 산출용 C 소프트웨어 레퍼런스 모델
    └── main.c                 # GIC 인터럽트/Data Abort 핸들러, 4대 검증 시나리오 및 성능 벤치마크 오케스트레이션

```

---

## 3. Data Structures & Global Variable Blocks

### 3.1 Hardware Register & Vector Structures

| 구조체명 | 정의 파일 | 내부 필드 구성 | 역할 및 메모리 정렬 특성 |
| :--- | :--- | :--- | :--- |
| **`SHA256_RegMap`** | `sha256_hal.h` | `ID`(`0x00`), `CTRL`(`0x04`), `STATUS`(`0x08`), `INTCLEAR`(`0x0C`), `MSG_LEN_LO/HI`(`0x10/14`), `DIGEST[8]`(`0x20~3C`), `STATE_IN[8]`(`0x80~9C`) | `0x40000000` 베이스 주소에 매핑되는 CSR 구조체. RO 레지스터는 `volatile const`로 선언하여 컴파일 타임 오쓰기 방지 |
| **`SHA256_VecHeader_t`** | `sd_parser.h` | `uint32_t bit_len`<br>`uint32_t byte_len`<br>`uint32_t golden_md[8]` | `__attribute__((packed))` 적용 고정 40-Byte 헤더. SD 카드 `.BIN` 파일에서 단일 `f_read()` 호출로 메타데이터와 Golden 해시 추출 |
| **`SHA256_TestVector_t`** | `sd_parser.h` | `bit_len`, `byte_len`, `golden_md[8]`, `uint8_t msg[16384]` | `msg` 버퍼에 `__attribute__((aligned(64)))`를 적용하여 Cortex-A9 캐시 라인(32B) 및 DMA 버스트 경계 정렬 보장 |
| **`SW_SHA256_CTX`** | `sha256_ref_model.h` | `uint8_t data[64]`, `uint32_t datalen`, `uint64_t bitlen`, `uint32_t H[8]` | PS 영역 C 레퍼런스 모델의 컨텍스트 구조체. 512-bit 블록 버퍼 및 중간 해시 상태값(`H[0..7]`) 유지 |

### 3.2 Key Global Variables (`main.c` & `sd_parser.c`)

| 변수명 | 타입 | 정의 위치 | 용도 및 동기화 방식 |
| :--- | :--- | :--- | :--- |
| `AxiDma` / `Intc` | `XAxiDma` / `XScuGic` | `main.c` | AXI DMA 및 Zynq GIC 인터럽트 컨트롤러 드라이버 인스턴스 |
| `g_tv` | `SHA256_TestVector_t` | `main.c` | 스택 오버플로우 방지를 위해 BSS 섹션에 정적 할당된 16KB 메시지 버퍼 및 테스트 벡터 컨테이너 |
| `g_dma_done_flag`<br>`g_dma_err_flag` | `volatile int` | `main.c` | `dma_mm2s_isr()`에서 갱신되는 MM2S 전송 완료 및 에러 발생 플래그 |
| `g_sha256_done_flag` | `volatile int` | `main.c` | `sha256_done_isr()`에서 갱신되는 해시 코어 연산 완료 플래그 |
| `g_data_abort_cnt` | `volatile int` | `main.c` | `axi_abort_exception_handler()`에서 누적되는 AXI 버스 예외(`SLVERR`/`DECERR`) 발생 횟수 카운터 |
| `g_fatfs` | `FATFS` | `sd_parser.c` | 논리 드라이브 `0:/` 마운트 상태를 유지하는 FatFs 파일 시스템 객체 |

---

## 4. Module API & Function Reference

### 4.1 `sha256_hal.c` (Hardware Abstraction Layer)

| 함수 원형 | 주요 동작 설명 |
| --- | --- |
| `int sha256_init(void)` | `ID` 레지스터(`0x41749591`) 일치 여부를 확인하고 `sha256_soft_reset()` 및 `sha256_load_default_iv()`를 호출하여 초기화를 수행 |
| `void sha256_soft_reset(void)` | `CTRL.SOFT_RESET`(Bit 3, W1P)에 `1`을 인가하여 Wrapper/Core FSM 및 내부 512-bit 버퍼(`block_b`), 카운터(`byte_cnt`, `msg_len`)를 즉시 초기화한 뒤, `INTCLEAR`(`CLR_DONE \| CLR_ERR`)를 기록하여 상태 플래그를 소거 (`STATE_IN` 레지스터 값은 유지됨) |
| `void sha256_load_default_iv(void)` | `STATE_IN_0~7`(`0x80~0x9C`)에 FIPS 180-4 표준 초기 해시 상수 8워드를 적재 |
| `void sha256_set_custom_iv(const uint32_t iv[8])` | 수동 체이닝(Manual Chaining) 검증을 위해 사용자 정의 중간 해시값 8워드를 `STATE_IN_0~7`에 적재 |
| `void sha256_start(int irq_enable)` | `CTRL` 레지스터에 `EN \| IRQ_EN`을 설정한 후 `START` 비트를 순차 인가하는 2단계 트랜잭션 트리거 수행 |
| `void sha256_clear_intr(uint32_t clr_mask)` | `INTCLEAR`(`0x0C`, W1C) 레지스터에 `CLR_DONE`(Bit 1) 또는 `CLR_ERR`(Bit 2) 마스크를 기록하여 인터럽트 및 상태 플래그 해제 |
| `uint64_t sha256_get_msg_bitlen(void)` | `MSG_LEN_HI`와 `MSG_LEN_LO`를 읽어 64-bit 전체 수신 메시지 비트 길이를 반환 |
| `void sha256_read_digest(uint32_t digest[8])` | `DIGEST_0~7`(`0x20~0x3C`) 레지스터에서 256-bit 최종 해시 결과를 읽어 배열에 저장 |

### 4.2 `dma_utils.c` (AXI DMA & Cache Coherency Layer)

| 함수 원형 | 주요 동작 설명 |
| --- | --- |
| `int dma_init(XAxiDma *dma_inst_ptr)` | Base Address(`0x40400000`) 기반으로 DMA를 초기화하고 Simple Mode 확인 후 MM2S 완료/에러 인터럽트를 활성화 |
| `int dma_send_stream(XAxiDma *dma_inst_ptr, const uint8_t *tx_buf, uint32_t byte_len)` | 송신 버퍼에 대해 `Xil_DCacheFlushRange()`를 호출하여 DDR 메모리 일관성을 확보한 뒤 `XAxiDma_SimpleTransfer()`로 MM2S 전송 시작 |
| `void dma_recover(XAxiDma *dma_inst_ptr)` | DMA 오류 발생 시 하드웨어 리셋을 수행하고 인터럽트 설정을 복구 |

### 4.3 `sd_parser.c` (SD Card Binary Test Vector Loader)

| 함수 원형 | 주요 동작 설명 |
| --- | --- |
| `int sd_mount(void)` / `void sd_unmount(void)` | `f_mount()`를 호출하여 SD 카드(`0:/`)를 마운트 및 언마운트 |
| `int sd_open_file(FIL *fil, const char *filepath)` | 지정된 경로의 이진 테스트 벡터 파일(`0:/SHORT_TV.BIN`, `0:/LONG_TV.BIN`)을 읽기 전용(`FA_READ`)으로 오픈 |
| `int sd_read_next_vector(FIL *fil, SHA256_TestVector_t *vec)` | 40-Byte 고정 헤더(`SHA256_VecHeader_t`)를 먼저 읽고, `byte_len > 0`인 경우 해당 바이트만큼 `vec->msg`에 직접 읽어 들임 (EOF 시 `0` 반환) |

### 4.4 `main.c` (Interrupts, Exception Recovery & Test Orchestration)

| 함수 원형 | 주요 동작 설명 (`Verification_Plan.xlsx` `direct` 시트 매핑) |
| :--- | :--- |
| `static void gtimer_init(void)`<br>`static uint64_t gtimer_get_ticks(void)` | Cortex-A9 64-bit Global Timer(`0xF8F00200`)를 활성화하고 상위/하위 32비트 롤오버(Roll-over) 방어 루프를 통해 64-bit 정밀 틱을 반환 |
| `static void dma_mm2s_isr(void *callback_ref)`<br>`static void sha256_done_isr(void *callback_ref)` | GIC ID `61`(DMA) 및 `62`(SHA-256) 인터럽트 서비스 루틴. 하드웨어 인터럽트 펜딩 비트를 클리어하고 완료 플래그(`g_sha256_done_flag`)를 설정 |
| `static void axi_abort_exception_handler(void *data)` | 의도적인 `SLVERR`/`DECERR` 접근 시 발생하는 ARM Data Abort 예외 처리기. `DFSR`을 확인하여 동기식 Abort(`DFSR[10]==0`)인 경우 스택의 `LR_abt`(`DataAbortAddr + 8`)를 `+4`/`+2` 보정하여 무한 재실행 방지 |
| `static int run_pl_sha256_irq(...)` | 타이머 시작 $\rightarrow$ `sha256_start(1)` $\rightarrow$ `dma_send_stream()` $\rightarrow$ 인터럽트 플래그 대기 $\rightarrow$ 타이머 종료를 캡슐화한 순수 PL 실행 및 지연 측정 함수 |
| `static int test_basic_vectors(void)`<br>`static int test_padding_and_chaining(void)`<br>`static int test_negative_exceptions(void)`<br>`static int run_sd_bin_suite(const char *filepath)` | • **`[Test 1]` (`[FPGA-01]`):** 기본 벡터 3종(3B, 56B, 43B) 인터럽트 구동 및 PS 대조<br>• **`[Test 2]` (`[FPGA-02, 03]`):** 패딩 경계(1/55/56/64B), 다중 블록(128/192B) Auto-Chaining 및 `STATE_IN` Custom IV 수동 체이닝 검증<br>• **`[Test 3]` (`[FPGA-05~08]`):** Atomicity 위반(Async Abort 1회, `STATUS=0x05`), Soft-Reset 복구, RO 쓰기/WO 읽기/미할당 읽기(Async 1회 + Sync 2회, 누적 4회), MMU Non-Secure TrustZone 방화벽(Sync 1회 + Async 1회, 누적 6회) 검증<br>• **`[Test 4]` (`[FPGA-04, 09]`):** SD 카드 CAVP 이진 벡터(`SHORT_TV.BIN` 65종 중 `Len=0` SW 검증 + 64종 PL 구동, `LONG_TV.BIN` 64종 PL 구동) 전수 대조 및 PS vs. PL Throughput 산출 |

---

## 5. Key Technical Mechanisms

1. **비대칭 캐시 일관성 제어 (Asymmetric Cache Coherency):**
* **송신(PS DDR $\rightarrow$ PL DMA):** `S_AXI_HP0` 포트는 L1/L2 캐시를 경유하지 않고 DDR을 직접 읽으므로 전송 직전 `Xil_DCacheFlushRange()`를 수행합니다.
* **수신(PL CSR $\rightarrow$ PS CPU):** 연산 결과인 `DIGEST[0..7]`은 DMA가 아닌 `M_AXI_GP0`(Device Memory 속성, Non-cacheable)를 통해 CPU가 직접 읽으므로 `Xil_DCacheInvalidateRange()` 호출이 불필요합니다.

2. **Synchronous vs. Asynchronous Data Abort 복구 메커니즘 (`[Test 3]` 총 6회 Abort 분류):**
* **Synchronous Abort (`DFSR[10]==0`, 총 3회 — Read 위반):** 잘못된 주소 읽기(`LDR`)인 `INTCLEAR` 읽기(`0x0C`), 미할당 영역 읽기(`0x40`), Non-Secure `ID` 읽기 시 발생합니다. CPU가 읽기 응답(`RRESP = DECERR/SLVERR`)을 대기하다가 즉시 트랩되므로, BSP 벡터 테이블의 `subs pc, lr, #8` 명령이 오류 명령어를 다시 가리키지 않도록 스택 내 `LR_abt`를 명령어 길이(`4B`/`2B`)만큼 증가시켜 다음 명령어로 복귀시킵니다.
* **Asynchronous Abort (`DFSR[10]==1`, 총 3회 — Write 위반):** 잘못된 주소 쓰기(`STR`)인 Busy 중 `STATE_IN[0]` 쓰기(`0x80`), RO `ID` 쓰기(`0x00`), Non-Secure `STATE_IN[0]` 쓰기 시 발생합니다. AXI Write 버퍼를 거쳐 명령어가 이미 통과한 뒤 응답(`BRESP = SLVERR`)이 도착하므로, 각 쓰기 직후 `dsb()` 배리어로 예외 발생 시점을 동기화하고 `DFSR`만 클리어합니다.

3. **Zero-Length (`Len = 0`) 벡터 예외 처리 및 성능 계측 분리 (`[Test 4]`):**
* NIST `SHA256ShortMsg.rsp`의 첫 번째 벡터인 `Len = 0`(`0 bits`)은 AXI DMA SimpleTransfer의 최소 전송 길이(1 Byte) 제약 및 IP의 Null Beat(`TKEEP=4'b0000`) 방화벽 정책에 의해 PL DMA 구동 대상에서 제외(`waived_cnt = 1`)됩니다.
* `run_sd_bin_suite()`는 `bit_len == 0` 감지 시 PS 소프트웨어 모델(`sw_sha256_oneshot`)로 Golden 해시(`e3b0c442...`) 정합성을 확인하여 전체 PASS 카운트(`65/65 Passed`)에 반영하되, PL/PS 타이머 틱 누적(`total_pl_ticks`, `total_ps_ticks`)에서는 제외하여 순수 하드웨어 스트리밍이 수행된 64개 벡터(`16,640 bits`)만으로 왜곡 없는 Throughput을 산출합니다.

