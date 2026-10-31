# AXI4-Lite UVM VIP User Guide

## 1. Overview

본 Verification IP(VIP)는 AMBA AXI4-Lite 프로토콜 사양을 준수하는 UVM 1.2 기반 검증 컴포넌트입니다.

* **툴체인 호환성:** Xilinx Vivado Simulator(xsim) 및 오픈소스 레지스터 맵 생성기(PeakRDL) 환경에서 검증되었습니다.
* **동적 환경 지원:** 32-bit 및 64-bit 데이터 폭(Data Width)을 지원하며, 런타임에 동적으로 설정할 수 있습니다.
* **설계 철학:** Siemens Verification Academy의 `apb_agent` 구조를 벤치마킹하여 Dual-Top (UVM 클래스 - BFM 분리) 아키텍처로 구현되었습니다.

## 2. Integration & Configuration

### 2.1. Interface & BFM Connection

VIP는 핀 레벨 제어를 위해 `axi4lite_if`와 두 개의 BFM(`axi4lite_monitor_bfm`, `axi4lite_driver_bfm`)을 사용합니다. 테스트벤치 최상위 모듈(`tb_top`)에서 이를 인스턴스화하고 가상 인터페이스 형태로 `uvm_config_db`에 등록해야 합니다.

```systemverilog
// tb_top.sv
import uvm_pkg::*;
import axi4lite_agent_pkg::*;

module tb_top;
  logic clk, reset_n;

  // 1. Interface 및 BFM 인스턴스화
  axi4lite_if vif(.clk(clk), .reset_n(reset_n));
  
  axi4lite_monitor_bfm mon_bfm(
    .clk(clk), .reset_n(reset_n),
    .awaddr(vif.awaddr), .awprot(vif.awprot), .awvalid(vif.awvalid), .awready(vif.awready),
    /* 하위 핀 매핑 생략 */
  );
  
  axi4lite_driver_bfm drv_bfm(
    .clk(clk), .reset_n(reset_n),
    .awaddr(vif.awaddr), .awprot(vif.awprot), .awvalid(vif.awvalid), .awready(vif.awready),
    /* 하위 핀 매핑 생략 */
  );

  // 2. uvm_config_db에 등록 (Env 계층으로 전달)
  initial begin
    uvm_config_db#(virtual axi4lite_if)::set(null, "uvm_test_top.env.m_agent*", "vif", vif);
    uvm_config_db#(virtual axi4lite_monitor_bfm)::set(null, "uvm_test_top.env.m_agent*", "mon_bfm", mon_bfm);
    uvm_config_db#(virtual axi4lite_driver_bfm)::set(null, "uvm_test_top.env.m_agent*", "drv_bfm", drv_bfm);
  end
endmodule

```

### 2.2. Agent Configuration (`axi4lite_agent_config`)

VIP를 인스턴스화하기 전, 환경(Env) 또는 테스트(Test) 단계에서 `axi4lite_agent_config` 객체를 생성하여 VIP의 동작을 제어합니다. 주요 파라미터는 다음과 같습니다.

* **`DATA_WIDTH` / `ADDR_WIDTH` (int):** 데이터 버스 폭(32 또는 64) 및 주소 폭을 설정합니다. (기본값: 32). 지원되지 않는 데이터 폭 설정 시 `UVM_FATAL`이 발생합니다.


* **`active` (`uvm_active_passive_enum`):** `UVM_ACTIVE` 설정 시 마스터(Driver)로 동작하며, `UVM_PASSIVE` 설정 시 버스 신호 모니터링만 수행합니다. (기본값: `UVM_ACTIVE`).


* **`has_functional_coverage` (bit):** 프로토콜 커버리지 모니터 활성화 여부를 결정합니다.


* **`enable_random_delay` (bit):** RAL 어댑터 사용 시, 채널별 핸드셰이크 딜레이를 0이 아닌 무작위 값으로 인가할지 결정합니다.


* **`disable_alignment_sva` / `disable_timeout_sva` (bit):** 에러 주입 테스트 시 인터페이스의 Protocol Assertion(SVA) 위반 검사를 동적으로 비활성화합니다.



### 2.3. Agent Instantiation

검증 환경(Env) 클래스의 `build_phase`에서 Config 객체를 완성한 뒤, 고정된 문자열인 `"axi4lite_agent_config"`를 식별자(ID)로 사용하여 Agent 하위로 전달합니다.

```systemverilog
// env.sv
class my_env extends uvm_env;
  axi4lite_agent m_agent;
  axi4lite_agent_config m_cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // 1. Config 객체 생성 및 파라미터 설정
    m_cfg = axi4lite_agent_config::type_id::create("m_cfg");
    m_cfg.active = UVM_ACTIVE;
    m_cfg.DATA_WIDTH = 64;
    m_cfg.has_functional_coverage = 1;

    // 2. 가상 인터페이스 및 BFM 핸들 할당
    if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", m_cfg.vif))
      `uvm_fatal("ENV", "Cannot get vif")
    if (!uvm_config_db#(virtual axi4lite_monitor_bfm)::get(this, "", "mon_bfm", m_cfg.mon_bfm))
      `uvm_fatal("ENV", "Cannot get mon_bfm")
    if (!uvm_config_db#(virtual axi4lite_driver_bfm)::get(this, "", "drv_bfm", m_cfg.drv_bfm))
      `uvm_fatal("ENV", "Cannot get drv_bfm")

    // 3. Agent 하위로 Config 객체 전달 및 Agent 생성
    uvm_config_db#(axi4lite_agent_config)::set(this, "m_agent*", "axi4lite_agent_config", m_cfg);
    m_agent = axi4lite_agent::type_id::create("m_agent", this);
  endfunction
endclass

```

## 3. Sequence API & Transaction Control

VIP가 버스 트랜잭션을 발생시키도록 제어하려면 인터페이스를 직접 조작하지 않고, UVM Sequence를 통해 `axi4lite_seq_item` 객체를 생성하고 제약(Constraint)을 걸어 구동해야 합니다.

### 3.1. Transaction Knobs (`axi4lite_seq_item`)

사용자는 시퀀스 아이템 내부에 정의된 변수(Knobs)들을 `randomize() with` 구문으로 제어하여 원하는 시나리오를 구성할 수 있습니다.

* **기본 제어 변수:**
* `dir`: 트랜잭션 방향을 지정합니다 (`axi4lite_seq_item::WRITE` 또는 `axi4lite_seq_item::READ`).
* `addr`, `wdata`, `wstrb`, `prot`: AXI 채널 제어 변수입니다.
* *참고:* 32-bit 모드(`DATA_WIDTH=32`)로 구동할 경우, `addr`과 `wdata`는 64-bit로 선언되어 있으나 하위 32비트만 유효하게 사용됩니다. 상위 32비트에는 0을 패딩하거나 무시해도 VIP 내부 모니터에서 안전하게 마스킹 처리됩니다.

* **딜레이 제어 변수 (0~20 사이클):**
* `aw_delay`, `w_delay`, `b_delay` (Write 채널)
* `ar_delay`, `r_delay` (Read 채널)

* **에러 주입 제어 변수 (Error Injection):** 네거티브 테스트 시 프로토콜 위반을 강제합니다. 기본값은 비활성화(`1'b0`)입니다.
* `force_unaligned_addr`: 비정렬(Unaligned) 주소를 강제로 인가합니다.
* `force_invalid_wstrb`: 데이터 폭에 맞지 않는 잘못된 스트로브(`8'h00`) 패턴을 시퀀스 단에서 생성 후, 물리 계층에서 반전 인가(`8'hFF`)하여 비정상 패턴을 유도합니다.
* `ignore_ready_timeout`: 타임아웃 예외를 무시하거나 발생을 유도합니다.

### 3.2. Base & Utility Sequences

VIP 패키지(`axi4lite_agent_pkg`)에는 검증에 즉시 활용할 수 있는 기본 시퀀스들이 포함되어 있습니다.

* **단일 트랜잭션 (`axi4lite_read_seq`, `axi4lite_write_seq`)**
* 목적: 특정 주소에 대한 단일 읽기/쓰기를 수행합니다.
* 사용법: 사용자는 시퀀스 내부의 `addr`, `wdata`, `wstrb`, `prot` 변수에 직접 값을 할당하거나 제약을 걸어 구동합니다.

* **부분 쓰기 (`axi4lite_partial_write_seq`)**
* 목적: `wstrb`가 `8'h00` (All 0) 또는 `8'hFF` (All 1)가 아닌, 일부 바이트만 선별적으로 기록하는 트랜잭션을 발생시킵니다.
* 사용법: `addr`, `wdata`, `wstrb` 변수를 제약하여 구동합니다.

* **주소 순회 (`axi4lite_sweep_seq`)**
* 목적: `start_addr`부터 `end_addr`까지 지정된 간격(`stride`: 4 또는 8바이트)으로 순차 증가하며 Write와 Read를 번갈아 수행합니다. 메모리나 레지스터 맵의 일괄 검증에 유용합니다.

* **프로토콜 커버리지 달성 (`axi4lite_protocol_cov_seq`)**
* 목적: 커버리지 100% 달성을 위해 특정 채널 딜레이(Delay 0 등)와 Strobe 패턴의 조합을 정교하게 강제하는 유틸리티 시퀀스입니다.

### 3.3. Error Injection Guide
DUT의 에러 처리 로직(예: SLVERR 응답, 버스 복구)을 검증하려면 에러 주입 시퀀스(`axi4lite_err_inject_seq`)를 템플릿으로 활용하거나 직접 시퀀스를 작성합니다.
비정렬 주소 등 인터페이스 프로토콜 규격 자체를 위반하는 인젝션 시에만 선택적으로 비활성화해야 합니다. 그렇지 않으면 시뮬레이터가 프로토콜 위반을 감지하여 시뮬레이션을 강제 종료(`$fatal`)시킵니다.

**에러 주입 시나리오 작성 예시:**
```systemverilog
task run_error_scenario();
  axi4lite_err_inject_seq err_seq;
  err_seq = axi4lite_err_inject_seq::type_id::create("err_seq");

  // 1. 에러 주입 전: Config를 통해 SVA 위반 검사 비활성화
  m_cfg.disable_alignment_sva = 1;
  m_cfg.vif.disable_alignment_sva = 1; 

  // 2. 에러 트랜잭션 구동 (예: 무작위 비정렬 주소 및 Timeout 무시)
  if (!err_seq.randomize() with {
        num_rand_err_trans == 10;
      })
    `uvm_fatal("TEST", "Failed to randomize err_seq")
  err_seq.start(m_env.m_agent.m_sequencer);

  // 3. 에러 검증 완료 후: SVA 검사 복구
  m_cfg.disable_alignment_sva = 0;
  m_cfg.vif.disable_alignment_sva = 0;
endtask

```

## 4. UVM RAL Integration (레지스터 모델 연동)

UVM 레지스터 모델(RAL)을 사용하는 검증 환경을 위해 `reg2axi4lite_adapter` 클래스를 제공합니다. 이 어댑터는 RAL의 표준 트랜잭션(`uvm_reg_bus_op`)을 `axi4lite_seq_item`으로 변환하며, Byte Enable 기능을 지원합니다.

### 4.1. 레지스터 모델 어댑터 연결

검증 환경(Env)의 `connect_phase`에서 레지스터 모델의 맵(`default_map` 등)에 VIP의 시퀀서와 어댑터를 연결하여 사용합니다.

```systemverilog
// env.sv
class my_env extends uvm_env;
  my_reg_block m_regmodel;
  axi4lite_agent m_agent;
  reg2axi4lite_adapter m_adapter;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // 어댑터 인스턴스화
    m_adapter = reg2axi4lite_adapter::type_id::create("m_adapter");
    // ... (Agent 및 RegModel 생성 로직 생략) ...
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // 시퀀서 및 어댑터를 레지스터 맵에 연결
    if (m_regmodel.get_parent() == null) begin
      m_regmodel.default_map.set_sequencer(m_agent.m_sequencer, m_adapter);
      m_regmodel.default_map.set_auto_predict(1); // Implicit prediction 사용 시
    end
  endfunction
endclass

```

#### 4.2. 무작위 지연(Random Delay) 활성화 설정

기본적으로 어댑터를 통한 레지스터 접근은 모든 채널의 지연 시간(Wait State)이 0 사이클로 고정되어 가장 빠른 속도로 통신합니다. 하지만 `enable_random_delay = 1`로 설정할 경우, 레지스터를 읽고 쓸 때마다 AXI 각 채널의 Valid-Ready 핸드셰이크 과정에 0~20 사이클 사이의 무작위 지연 시간이 인가됩니다. 이를 통해 실제 혼잡한 버스 트래픽과 유사한 스트레스 환경을 구성할 수 있습니다.

어댑터와 에이전트는 내부적으로 `uvm_config_db`에서 `"axi4lite_agent_config"`라는 이름(ID)으로 설정 객체를 검색합니다. 따라서 이 기능을 사용하려면 Config 객체 등록 시 해당 식별자를 일치시켜야 합니다.

```systemverilog
// 설정 및 등록 예시 (test_base.sv 또는 env.sv)
m_cfg = axi4lite_agent_config::type_id::create("m_cfg");
m_cfg.enable_random_delay = 1; // 0~20 사이클 무작위 지연 시간 발생 활성화

// 중요: 에이전트 및 어댑터가 참조할 수 있도록 "axi4lite_agent_config" 이름으로 DB에 등록
uvm_config_db#(axi4lite_agent_config)::set(null, "*", "axi4lite_agent_config", m_cfg);
```

## 5. Coverage Waiver Guide (커버리지 예외 처리)

VIP에 내장된 `axi4lite_coverage_monitor`는 ARM 표준 AXI4-Lite 규격을 기준으로 모든 경우의 수를 검증하도록 100% 커버리지를 요구합니다.

하지만 연동하고자 하는 타겟 DUT의 하드웨어 스펙에 따라 특정 기능(예: 특정 에러 응답 미지원, 내부 버퍼로 인한 즉시 응답 불가)이 구조적으로 발생할 수 없는 경우가 존재합니다. 이 경우 커버리지 도달률 모수에서 해당 항목을 제외(Waiver)하여 달성률을 보정해야 합니다.

### 5.1. Xilinx Simulator (Vivado xsim) 제약 및 우회 방식

일반적인 UVM 환경에서는 테스트벤치 단계에서 특정 Covergroup의 가중치를 0으로 설정(`option.weight = 0`)하여 무효화하는 방식을 사용합니다. 하지만 **Xilinx Vivado (2025.2 버전 기준)** 시뮬레이터는 이러한 동적 가중치 제어나 복잡한 `cross + binsof` 문법을 처리할 때 안정성 문제가 발생하거나 일부 미지원하는 한계가 존재합니다.

따라서 본 VIP를 Vivado 환경에서 사용할 때의 가장 확실하고 안전한 Waiver 방식은 다음과 같습니다.

1. 예외적으로 VIP 원본 코드인 `axi4lite_coverage_monitor.svh`를 직접 수정하여 DUT 환경에 맞춥니다.
2. 도달 불가능한 단일 조건에 대해 명시적으로 `ignore_bins`를 선언하여 원본 규격을 덮어씁니다(Override).
3. 불가능한 타이밍 조합의 경우, Cross 자체를 삭제하지 않고 Cross 내부 조건이나 삼항 연산자를 이용한 **Conditional Coverpoint**로 우회하여 작성합니다.

### 5.2. Waiver 적용 사례 및 가이드

새로운 타겟 DUT에 VIP를 연동할 때, DUT 사양서에 명시된 한계점을 파악하고 아래의 실무 적용 예시를 참고하여 `axi4lite_coverage_monitor.svh` 코드를 수정하십시오.

* **사례 1: B/R 채널 지연 (`back_to_back` 불가)**
DUT 내부 구조상 순차 논리(always_ff) 버퍼를 거쳐 응답하므로, Valid 인가 즉시 0-cycle(Wait State 0)로 Ready 응답을 주는 것이 물리적으로 불가능한 경우입니다. `B_DELAY` 및 `R_DELAY` 항목에서 `back_to_back = {0}` 조건을 모수에서 제외합니다.
* **사례 2: 미지원 에러 응답 (`DECERR` 불가)**
타겟 DUT가 주소 디코드 에러(`DECERR`) 기능을 지원하지 않고 오직 `SLVERR`만 반환하는 경우, 에러 응답 항목(`ERR_RESP`)에서 `decerr = {2'b11}` 조건을 모수에서 제외합니다.

**적용 코드 스니펫 (`axi4lite_coverage_monitor.svh` 수정 예시):**

```systemverilog
  // 1. 0-cycle 응답이 불가능한 DUT를 위한 Waiver 처리
  B_DELAY: coverpoint txn.b_delay iff (txn.dir == axi4lite_seq_item::WRITE) {
    // bins back_to_back = {0}; // 원본 표준 규격
    ignore_bins back_to_back = {0}; // 타겟 DUT 한계 반영 (Waiver 적용)
    bins delayed = {[1 : 20]};
  }

  // 2. DECERR 응답이 불가능한 DUT를 위한 Waiver 처리
  ERR_RESP: coverpoint txn.resp {
    bins slverr = {2'b10};
    // bins decerr = {2'b11}; // 원본 표준 규격
    ignore_bins decerr = {2'b11}; // 타겟 DUT 한계 반영 (Waiver 적용)
  }

```

## 6. Example Tests

VIP 패키지에는 검증 환경 연동 및 시나리오 작성법을 참고할 수 있는 템플릿 코드들이 포함되어 있습니다. 특정 타겟 DUT에 종속된 로직을 제외하고, VIP 제어 및 시퀀스 호출의 핵심 패턴을 요약하여 제공합니다.

### 6.1. Base Test (환경 설정 및 연동)

모든 테스트의 부모 클래스가 되는 `test_base`에서는 `axi4lite_agent_config` 객체를 생성하여 기본 동작 파라미터를 설정하고 `uvm_config_db`에 등록합니다.

```systemverilog
class example_test_base extends uvm_test;
  `uvm_component_utils(example_test_base)

  axi4lite_agent_config m_axi4lite_agent_cfg;
  // ... (Env 및 RAL 모델 선언 생략) ...

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // 1. VIP Config 객체 생성 및 설정
    m_axi4lite_agent_cfg = axi4lite_agent_config::type_id::create("m_axi4lite_agent_cfg");
    m_axi4lite_agent_cfg.active = UVM_ACTIVE;
    m_axi4lite_agent_cfg.has_functional_coverage = 1;
    m_axi4lite_agent_cfg.ADDR_WIDTH = 32;
    m_axi4lite_agent_cfg.DATA_WIDTH = 32;

    // 2. 기본 SVA 상시 감시 활성화(0) 및 Random Delay 초기 설정
    m_axi4lite_agent_cfg.disable_alignment_sva = 0;
    m_axi4lite_agent_cfg.disable_timeout_sva = 0;
    m_axi4lite_agent_cfg.enable_random_delay = 0;

    // 3. Env 및 RAL 어댑터가 참조할 수 있도록 DB에 등록 (이름: "axi4lite_agent_config")
    uvm_config_db#(axi4lite_agent_config)::set(this, "*", "axi4lite_agent_config", m_axi4lite_agent_cfg);
    
    // ... (Env 빌드 로직 생략) ...
  endfunction
endclass
```

### 6.2. Protocol Coverage Test (정상 트래픽 및 Delay 인가)

커버리지 달성이나 핸드셰이크 스트레스 검증을 위해 지연 시간(Random Delay) 옵션을 활성화하고 VIP 내장 유틸리티 시퀀스를 구동하는 예제입니다.

```systemverilog
class example_protocol_test extends example_test_base;
  `uvm_component_utils(example_protocol_test)

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Base Test의 설정을 덮어써서 무작위 채널 지연 활성화
    m_axi4lite_agent_cfg.enable_random_delay = 1;
  endfunction

  virtual task run_phase(uvm_phase phase);
    axi4lite_protocol_cov_seq protocol_seq;

    phase.raise_objection(this);

    // VIP 내장 프로토콜 시퀀스 구동
    protocol_seq = axi4lite_protocol_cov_seq::type_id::create("protocol_seq");
    if (!protocol_seq.randomize()) `uvm_fatal("TEST", "Randomization failed")
    
    // RAL 모델에 연결된 시퀀서(또는 VIP 시퀀서)를 타겟으로 실행
    protocol_seq.start(m_env_cfg.csr_rb.default_map.get_sequencer());

    phase.drop_objection(this);
  endtask
endclass

```

### 6.3. Error Injection Test (네거티브 테스트)

DUT의 에러 처리 로직을 검증하기 위해 프로토콜 위반 트랜잭션을 강제로 발생시키는 예제입니다. 에러 주입 구간 전후로 SVA 검사(`disable_alignment_sva`, `disable_timeout_sva`)를 동적으로 마스킹(`1`)한 뒤 복구(`0`)합니다.

```systemverilog
class example_err_test extends example_test_base;
  `uvm_component_utils(example_err_test)

  virtual task run_phase(uvm_phase phase);
    axi4lite_err_inject_seq err_inject_seq;
    uvm_status_e status;

    phase.raise_objection(this);

    // 1. RAL을 통한 정상 설정 (SVA 상시 감시 상태)
    m_env_cfg.csr_rb.CONTROL.mode.set(3);
    m_env_cfg.csr_rb.CONTROL.update(status);

    // 2. 에러 트랜잭션 주입 전 SVA 동적 마스킹
    m_axi4lite_agent_cfg.disable_alignment_sva = 1;
    m_axi4lite_agent_cfg.disable_timeout_sva   = 1;
    m_axi4lite_agent_cfg.vif.disable_alignment_sva = 1;
    m_axi4lite_agent_cfg.vif.disable_timeout_sva   = 1;

    err_inject_seq = axi4lite_err_inject_seq::type_id::create("err_inject_seq");
    if (!err_inject_seq.randomize()) `uvm_fatal("TEST", "Randomization failed")
    err_inject_seq.start(m_env_cfg.csr_rb.default_map.get_sequencer());

    // 3. 에러 주입 완료 후 SVA 감시 복구
    m_axi4lite_agent_cfg.disable_alignment_sva = 0;
    m_axi4lite_agent_cfg.disable_timeout_sva   = 0;
    m_axi4lite_agent_cfg.vif.disable_alignment_sva = 0;
    m_axi4lite_agent_cfg.vif.disable_timeout_sva   = 0;

    phase.drop_objection(this);
  endtask
endclass
```

### 6.4. Advanced: RAL과 Raw Sequence 혼합 사용

현업 검증 시, 레지스터 맵(RAL)을 통한 설정과 VIP의 원시(Raw) 시퀀스를 통한 고속 데이터 푸시를 동일한 시퀀서에서 혼합하여 사용하는 기법입니다. 레지스터 어댑터 제약을 우회하여 특정 주소 영역에 임의의 값을 빠르게 밀어 넣을 때 유용합니다.

```systemverilog
class advanced_mixed_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(advanced_mixed_vseq)

  virtual task body();
    axi4lite_write_seq raw_wr_seq;
    uvm_status_e status;
    uvm_sequencer_base sqr;

    // RAL 모델에서 시퀀서 핸들 획득
    sqr = csr_rb.default_map.get_sequencer();

    // 1. RAL을 이용한 표준 레지스터 제어
    csr_rb.CTRL.write(status, 32'h00000001);

    // 2. VIP Raw 시퀀스를 이용한 직접 트랜잭션 구동 (uvm_do_on_with 활용)
    `uvm_do_on_with(raw_wr_seq, sqr, {
      addr == 32'h0000_0040; 
      wdata == 32'h1111_1111;
    })
    
    // 3. 병렬 처리 (Fork-Join 내 혼합 사용)
    fork
      begin
        csr_rb.TRIGGER.write(status, 32'h00000001); // RAL Write
      end
      begin
        `uvm_do_on_with(raw_wr_seq, sqr, {
          addr == 32'h0000_0044; 
          wdata == 32'h2222_2222;
        }) // Raw VIP Write
      end
    join
  endtask
endclass

```