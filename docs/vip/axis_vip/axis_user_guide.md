# AXI4-Stream UVM VIP User Guide

## 1. Overview

본 Verification IP(VIP)는 AMBA AXI4-Stream 프로토콜 사양을 준수하는 UVM 1.2 기반 검증 컴포넌트입니다.

* **동적 환경 지원:** 런타임 Configuration 설정을 통해 Master 또는 Slave 모드로 동적 전환이 가능합니다.
* **설계 철학:** Siemens Verification Academy의 `apb_agent` 구조를 벤치마킹하여 Dual-Top (UVM 클래스 - BFM 분리) 아키텍처로 구현되었습니다.

## 2. Integration & Configuration

### 2.1. Interface & BFM Connection

VIP는 핀 제어 및 모니터링을 위해 단일 `axis_if`와 3개의 BFM(`axis_m_driver_bfm`, `axis_s_driver_bfm`, `axis_monitor_bfm`)을 사용합니다. Testbench 최상위 모듈(`tb_top`)에서 이들을 인스턴스화하고 가상 인터페이스(Virtual Interface) 형태로 `uvm_config_db`에 등록해야 합니다.

```systemverilog
// tb_top.sv
import uvm_pkg::*;
import axis_agent_pkg::*;

module tb_top;
  logic aclk, aresetn;

  // 1. Interface 및 BFM 인스턴스화
  axis_if vif(.aclk(aclk), .aresetn(aresetn));
  
  axis_monitor_bfm mon_bfm(.aclk(aclk), .aresetn(aresetn), .vif(vif));
  axis_m_driver_bfm m_drv_bfm(.aclk(aclk), .aresetn(aresetn), .vif(vif));
  axis_s_driver_bfm s_drv_bfm(.aclk(aclk), .aresetn(aresetn), .vif(vif));

  // 2. uvm_config_db에 등록 (Env 계층으로 전달)
  initial begin
    uvm_config_db#(virtual axis_m_driver_if)::set(null, "uvm_test_top.env.axis_agent*", "drv_m_bfm", m_drv_bfm);
    uvm_config_db#(virtual axis_s_driver_if)::set(null, "uvm_test_top.env.axis_agent*", "drv_s_bfm", s_drv_bfm);
    uvm_config_db#(virtual axis_monitor_if)::set(null, "uvm_test_top.env.axis_agent*", "mon_bfm", mon_bfm);
  end
endmodule

```

### 2.2. Agent Configuration (`axis_agent_config`)

VIP를 생성하기 전, 검증 환경(Env)에서 `axis_agent_config` 객체를 생성하여 VIP의 구조와 동작을 제어합니다. 주요 파라미터는 다음과 같습니다.

* **`is_active` (`uvm_active_passive_enum`):** `UVM_ACTIVE` 설정 시 Sequencer와 Driver가 활성화되며, `UVM_PASSIVE` 설정 시 모니터링 기능만 수행합니다. (기본값: `UVM_ACTIVE`)
* **`is_master` (bit):** `1`로 설정 시 Master 모드(`axis_m_driver`)로 동작하며, `0`으로 설정 시 Slave 모드(`axis_s_driver`)로 동작합니다. (기본값: `1`)
* **`arb_mode` (`axis_arb_mode_e`):** 다중 TID 패킷 전송 시 Arbitration 방식을 지정합니다. (`ARB_RR` 또는 `ARB_RANDOM`)
* **`timeout_cycles` (int):** TREADY 타임아웃 조건을 설정합니다. (기본값: 1000)
* **`active_data_width` / `active_user_width` (int):** 실제 검증에 사용할 논리적인 데이터 및 유저 신호 폭을 지정합니다. (기본값: 32)
* **`active_id_max` / `active_dest_max` (int):** 라우팅 제어를 위한 최대 허용 범위를 지정합니다.
* **`has_functional_coverage` (bit):** 프로토콜 커버리지 콜백(`axis_coverage`) 활성화 여부를 결정합니다.

### 2.3. Agent Instantiation

검증 환경의 `build_phase`에서 Config 객체를 생성하여 파라미터를 설정한 뒤, `"axis_agent_config"`라는 고정된 문자열을 식별자로 사용하여 Agent 하위로 전달합니다.

```systemverilog
// env.sv
class my_env extends uvm_env;
  axis_agent m_agent;
  axis_agent_config m_cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // 1. Config 객체 생성 및 파라미터 설정
    m_cfg = axis_agent_config::type_id::create("m_cfg");
    m_cfg.is_active = UVM_ACTIVE;
    m_cfg.is_master = 1;  // Master 모드 동작
    m_cfg.active_data_width = 64;
    m_cfg.has_functional_coverage = 1;

    // 2. 가상 인터페이스(BFM) 핸들 할당
    if (!uvm_config_db#(virtual axis_m_driver_if)::get(this, "", "drv_m_bfm", m_cfg.drv_m_bfm))
      `uvm_fatal("ENV", "Cannot get drv_m_bfm")
    if (!uvm_config_db#(virtual axis_s_driver_if)::get(this, "", "drv_s_bfm", m_cfg.drv_s_bfm))
      `uvm_fatal("ENV", "Cannot get drv_s_bfm")
    if (!uvm_config_db#(virtual axis_monitor_if)::get(this, "", "mon_bfm", m_cfg.mon_bfm))
      `uvm_fatal("ENV", "Cannot get mon_bfm")

    // 3. Agent 하위로 Config 객체 전달 및 Agent 생성
    uvm_config_db#(axis_agent_config)::set(this, "m_agent*", "axis_agent_config", m_cfg);
    m_agent = axis_agent::type_id::create("m_agent", this);
  endfunction
endclass

``` 

## 3. Sequence API & Transaction Control

VIP가 AXI4-Stream 트랜잭션을 발생시키도록 제어하려면 인터페이스를 직접 조작하지 않고, UVM Sequence를 통해 `axis_seq_item` 객체를 생성하여 구동해야 합니다.

### 3.1. Transaction Knobs (`axis_seq_item`)

사용자는 시퀀스 아이템 내부에 정의된 변수(Knobs)들을 `randomize() with` 구문으로 제어하여 원하는 스트림 패킷 시나리오를 구성할 수 있습니다.

* **기본 제어 변수 (Queue 기반):** AXI4-Stream은 패킷 단위 통신이므로 데이터가 배열 형태로 관리됩니다.
* `tdata_q`, `tstrb_q`, `tkeep_q`, `tuser_q`: 패킷을 구성하는 각 Beat의 데이터 및 Qualifier 신호 배열입니다.
* `tid`, `tdest`: 패킷 단위의 라우팅 목적지 변수입니다.
* *참고:* 배열의 크기(`tdata_q.size()`)가 곧 패킷의 길이(Beat 수)를 의미하며, 내부 제약 조건(`queue_size_limit_c`)에 의해 기본 1~64 Beat 사이로 제한됩니다.


* **딜레이 제어 변수:** 각 Beat마다 독립적인 딜레이 인가가 가능합니다.
* `valid_delay_q`: Master 구동 시 TVALID 어설트 전 대기 사이클(Inter-Packet Gap 등)을 제어합니다.
* `ready_delay_q`: Slave 구동 시 TREADY 어설트 전 대기 사이클(Back-pressure)을 제어합니다.

* **에러 주입 및 패킷 상태 변수 (Error Injection & Status):**
  * `drop_tlast`: 패킷의 마지막 Beat 전송 시 `TLAST` 어설트를 생략하여 슬레이브 수신 대기(Starvation) 상황을 유도합니다 (기본값: `1'b0`).
  * `force_tkeep_error`: 기본 연속 스트로브 제약(`tkeep_tstrb_rule_c`)을 해제하여 비정상 `TKEEP` 패턴 주입을 허용합니다 (기본값: `1'b0`).
  * `force_tvalid_drop`, `err_mid_pkt_tid_change`, `err_mid_pkt_tdest_change`: 전송 중 비정상 제어 신호 변경 시나리오를 위한 확장 플래그입니다.
  * `status` (`OK`, `INCOMPLETE`, `PROTOCOL_ERR`): 모니터가 패킷 재조립 시 기록하는 상태 플래그로, 정상 `TLAST` 종료 시 `OK`, 리셋이나 `reset_agent()` 플러시로 중단된 경우 `INCOMPLETE`가 할당됩니다.

### 3.2. Base & Utility Sequences

VIP 패키지는 실제 검증 환경에 즉시 연동하여 사용할 수 있도록 유틸리티 시퀀스들을 제공합니다. 모든 시퀀스는 `axis_base_seq`를 상속받아 Config 설정을 트랜잭션 아이템에 자동으로 적용합니다.

**Master Sequences (`is_master = 1` 환경에서 구동)**

* **단일 고속 트랜잭션 (`axis_m_single_seq`)**
  * 목적: `pkt_len` 크기만큼의 패킷을 Beat 간 지연 시간(`valid_delay = 0`) 없이 가장 빠른 속도로 전송합니다.
* **기본 무작위 버스트 전송 (`axis_m_basic_seq`)**
  * 목적: 지정된 `pkt_len`(기본 2~64 Beat) 크기의 패킷을 기본 딜레이 제약(`0~10` 사이클) 하에서 무작위 생성하여 전송합니다.
* **연속 바이트 스트림 전송 (`axis_m_stream_seq`)**
  * 목적: 사용자가 주입한 `payload_data` 바이트 배열을 활성 버스 폭(`active_data_width`)에 맞추어 자동으로 분할(Packing)하고, 마지막 Beat의 잔여 바이트 수에 맞는 연속 `TKEEP`과 `TLAST=1`을 생성하여 스트리밍합니다.
* **타이밍 스트레스 테스트 (`axis_m_short_delay_seq`, `axis_m_slow_seq`)**
  * 목적: `TVALID` 인가 시점에 1~5 사이클의 짧은 지연(Short delay) 또는 10~100 사이클 범위의 긴 지연(Slow)을 강제하여 DUT의 수신 버퍼 타이밍 마진을 테스트합니다. (`num_trans`, `pkt_len_min/max`, `delay_min/max` 제어 지원)
* **프로토콜 에러 주입 (`axis_m_err_inject_seq`)**
  * 목적: `do_tlast_drop = 1`을 통한 `TLAST` 누락 또는 `do_tkeep_err = 1`을 통한 비정상 `TKEEP` 패턴을 주입합니다. `do_tkeep_err` 활성화 시 설정된 `active_data_width` 폭 내에서 `do_tlast_drop == 1`이면 패킷 중간 부분 스트로브(Mid-packet Partial)를, `do_tlast_drop == 0`이면 비연속 스트로브(Sparse `TKEEP`)를 무작위로 생성합니다.

**Slave Sequence (`is_master = 0` 환경에서 구동)**

* **Back-pressure 제어 (`axis_s_single_seq`)**
  * 목적: Slave 모드로 구동할 때, `delay_length` 변수에 설정된 횟수만큼 `ready_delay_q`를 무작위로 생성하여 Master 측에 `TREADY` Back-pressure를 인가합니다.

### 3.3. Error Injection & Agent Reset (`reset_agent`) Guide

`TLAST`를 고의로 누락(`do_tlast_drop = 1`)시키거나 비정상 스트림 주입 후 DUT에 Soft Reset을 인가한 경우, VIP 내부의 Driver 송신 큐와 Monitor 재조립 큐에 미완성 패킷 데이터가 남아 있게 됩니다. 이때 하드웨어 리셋(`aresetn = 0`) 없이 에이전트 상태를 즉시 초기화하려면 `axis_agent::reset_agent()`를 호출합니다.

* **`m_axis_agent.reset_agent()` 동작:** Driver BFM(`flush()`)의 잔여 송신 큐를 즉시 비우고, Monitor BFM(`flush()`)에 수집 중이던 미완성 패킷을 `status = axis_seq_item::INCOMPLETE`로 Tag하여 Analysis Port로 Broadcast한 뒤 내부 카운터를 초기화합니다.


## 4. Interface Tuning & Customization

본 VIP는 다양한 데이터 폭(Data Width)을 가진 타겟 DUT에 코드 수정 없이 즉각적으로 대응하기 위해, 파라미터 매개변수화(Parameterized) 방식 대신 **Over-provisioning(물리 폭 고정 및 논리적 마스킹)** 방식을 사용합니다.

### 4.1. Over-provisioning 활용 가이드

`axis_if` 인터페이스의 모든 데이터 및 유저 신호는 최대 스펙인 **1024-bit로 고정 할당**되어 있습니다. 사용자는 타겟 DUT의 실제 버스 폭에 맞추어 `axis_agent_config`의 런타임 변수만 설정하면 됩니다.

* **동적 마스킹 (Dynamic Masking):**
* 설정 변수: `active_data_width`, `active_user_width`, `active_id_max`, `active_dest_max`
* 동작 원리: `axis_seq_item`이 생성(Randomize)될 때, 설정된 폭(Width)을 초과하는 상위 비트들은 내부 로직(`post_randomize`)에 의해 자동으로 `0`으로 마스킹됩니다.
* 바이트 제어: `tkeep`과 `tstrb` 역시 활성화된 바이트 크기(예: 32-bit인 경우 하위 4바이트)에 맞춘 `active_byte_mask` 규칙을 엄격히 따르게 됩니다.


**[적용 예시] 32-bit 타겟 DUT 연동 시**

```systemverilog
// Test 클래스의 build_phase 내부
m_cfg.m_axis_agent_cfg.active_data_width = 32;
// 1024-bit 물리 인터페이스 중 하위 32-bit만 유효 데이터로 사용되며, 
// 나머지 상위 992-bit는 0으로 고정(Zero-padding)되어 전송됩니다.

```

### 4.2. DUT 맞춤형 소스코드 튜닝 가이드

타겟 DUT의 고유한 하드웨어 스펙이나 예외적인 파이프라인 구조로 인해 VIP의 기본 동작(예: 타임아웃 조건)이 맞지 않을 경우, VIP 원본 코드를 일부 튜닝하여 사용할 수 있습니다.

* **TREADY 타임아웃 튜닝 (`wait_pkt_done`):**
* 현상: Master BFM(`axis_m_driver_bfm`)은 패킷 전송 중 TREADY가 장시간 비활성화될 경우 `timeout_cycles`를 기준으로 에러를 발생시킵니다.
* 튜닝 팁: DUT의 내부 버퍼 크기나 처리 속도에 의해 타임아웃이 필연적으로 길어지는 경우, Config의 `timeout_cycles`를 늘려주거나 BFM 코드 내부의 Timeout 에러 검출 로직(`if (wait_cnt > timeout_cycles)`)을 주석 처리하여 무한 대기 상태를 허용할 수 있습니다.

* **고정 패킷 길이 강제 (시퀀스 제약 조건):**
* 현상: 기본 시퀀스 아이템은 1~64 Beat 사이의 가변적인 패킷(`tdata_q.size()`)을 무작위로 생성합니다.
* 튜닝 팁: DUT가 항상 고정된 길이(예: 16 Beat 단위)의 스트림만 수신해야 하는 경우, 제공된 유틸리티 시퀀스 내부의 `pkt_len` 무작위 범위를 수정하거나, 새로운 Custom Sequence를 상속받아 패킷 길이 제약 조건을 덮어쓰는(Override) 방식을 권장합니다.

## 5. Coverage Waiver Guide

VIP에 내장된 `axis_coverage`는 ARM 표준 AXI4-Stream 규격을 기준으로 모든 경우의 수를 검증하도록 100% 커버리지를 요구합니다.

하지만 연동하고자 하는 타겟 DUT의 하드웨어 스펙에 따라 특정 기능(예: 라우팅 핀 미사용, 특정 응답 지연 불가)이 구조적으로 발생할 수 없는 경우가 존재합니다. 이 경우 커버리지 도달률 모수에서 해당 항목을 제외(Waiver)하여 달성률을 보정해야 합니다.

### 5.1. Xilinx Simulator (Vivado xsim) 제약 및 우회 방식

일반적인 UVM 환경에서는 테스트벤치 단계에서 특정 Covergroup의 가중치를 0으로 설정(`option.weight = 0`)하여 무효화하는 방식을 사용합니다. 하지만 **Xilinx Vivado (2025.2 버전 기준)** 시뮬레이터는 이러한 동적 가중치 제어나 복잡한 `cross + binsof` 문법을 처리할 때 안정성 문제가 발생하거나 일부 미지원하는 한계가 존재합니다.

따라서 본 VIP를 Vivado 환경에서 사용할 때의 가장 확실하고 안전한 Waiver 방식은 다음과 같습니다.

1. 예외적으로 VIP 원본 코드인 `axis_coverage.svh`를 직접 수정하여 DUT 환경에 맞춥니다.
2. 도달 불가능한 단일 조건에 대해 명시적으로 `ignore_bins`를 선언하여 원본 규격을 덮어씁니다(Override).
3. 불가능한 타이밍 조합의 경우, Cross 자체를 삭제하지 않고 Cross 내부 조건이나 삼항 연산자를 이용한 **Conditional Coverpoint**로 우회하여 작성합니다.

### 5.2. Waiver 적용 사례 및 가이드

새로운 타겟 DUT에 VIP를 연동할 때, DUT 사양서에 명시된 한계점을 파악하고 아래의 실무 적용 예시를 참고하여 `axis_coverage.svh` 코드를 수정하십시오.

* **사례 1: 라우팅 및 사이드밴드 핀 미사용 (TID, TDEST, TUSER)**
타겟 DUT가 데이터 스트림(`TDATA`, `TVALID`, `TREADY`, `TLAST`)만 사용하고 라우팅이나 유저 신호를 전혀 사용하지 않는 경우입니다. 무의미한 커버리지 미달(Miss)을 방지하기 위해 해당 Covergroup의 가중치를 0으로 끄거나 `ignore_bins`를 처리합니다.
* **사례 2: TREADY 배압(Back-pressure) 불가**
DUT 내부 버퍼가 항상 비워져 있어 TREADY를 낮추는(Stall) 상황이 물리적으로 발생하지 않는 경우입니다. Handshake 커버리지 항목에서 TREADY 지연 관련 구간(`short_backpressure` 등)을 제외해야 합니다.

**적용 코드 스니펫 (`axis_coverage.svh` 수정 예시):**

```systemverilog
  // 1. TUSER 핀을 사용하지 않는 DUT를 위한 Waiver 처리
  covergroup cg_sideband_type_mixed() with function sample(bit tlast, user_state_e user_state);
    option.per_instance = 1;
    option.weight = 0;  // 타겟 한계 반영: 전체 그룹 비활성화

    cp_tuser_state: coverpoint user_state {
      ignore_bins all_0 = {USER_ALL_0}; // 구체적인 bin 무시
      bins mixed = {USER_MIXED};
    }
    // ... 생략 ...
  endgroup

  // 2. TREADY 지연이 불가능한 DUT를 위한 Waiver 처리
  covergroup cg_handshake with function sample (int valid_wait_cycles, int ready_wait_cycles);
    // ... 생략 ...
    cp_ready_wait: coverpoint ready_wait_cycles {
      bins ready_first = {0};
      // 타겟 구조상 불가능한 Back-pressure 구간을 무시
      ignore_bins short_backpressure = {[1 : 5]}; 
      ignore_bins long_backpressure = {[6 : 20]};
      bins others = default;
    }
  endgroup

```


## 6. Integration Examples

이 챕터는 사용자가 테스트벤치를 구성하고 트랜잭션을 구동하는 방법을 참고할 수 있도록, 가장 기본적인 루프백(Loopback) 코드 템플릿을 제공합니다. 이 예시는 VIP의 master와 slave를 연결한 예제로, 사용하는 모드에 맞춰서 참고하면 됩니다. (제시된 코드는 UVM 환경 셋업과 시퀀스 호출의 핵심 뼈대만 요약한 것입니다.)

### 6.1. Environment Setup (Env & Config)

`test_base` 클래스에서 `axis_agent_config` 객체를 생성하여 기본 동작 파라미터를 설정하고 `uvm_config_db`에 등록합니다. 아래는 단일 환경에서 Master용과 Slave용 Agent를 각각 생성하고 설정하는 예시입니다.

```systemverilog
class axis_loopback_test_base extends uvm_test;
  `uvm_component_utils(axis_loopback_test_base)

  axis_loopback_env m_env;
  axis_loopback_env_config m_env_cfg;
  // ... (생략) ...

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    m_env_cfg = axis_loopback_env_config::type_id::create("m_env_cfg");
    m_env_cfg.m_axis_agent_cfg = axis_agent_config::type_id::create("m_axis_agent_cfg");
    m_env_cfg.s_axis_agent_cfg = axis_agent_config::type_id::create("s_axis_agent_cfg");

    // 1. Master Agent 설정
    m_env_cfg.m_axis_agent_cfg.is_active = UVM_ACTIVE;
    m_env_cfg.m_axis_agent_cfg.is_master = 1;
    m_env_cfg.m_axis_agent_cfg.active_data_width = 32;

    // 2. Slave Agent 설정
    m_env_cfg.s_axis_agent_cfg.is_active = UVM_ACTIVE;
    m_env_cfg.s_axis_agent_cfg.is_master = 0;
    m_env_cfg.s_axis_agent_cfg.active_data_width = 32;

    // ... (BFM 연결 및 uvm_config_db 등록 로직 생략) ...
    m_env = axis_loopback_env::type_id::create("m_env", this);
  endfunction
endclass

```

### 6.2. Master-Slave Loopback Test

루프백 VSEQ(Virtual Sequence) 내부에서 범용 루프백/CDV 환경 전용으로 제공되는 Master의 Basic 시퀀스와 Slave의 Basic 시퀀스를 `fork-join`으로 동시에 구동하여 기본 핸드셰이크를 발생시키는 예시입니다.


```systemverilog
class axis_loopback_basic_vseq extends axis_loopback_base_vseq;
  `uvm_object_utils(axis_loopback_basic_vseq)
  // ... (생략) ...

  virtual task body();
    axis_cdv_m_basic_seq m_seq;
    axis_cdv_s_basic_seq s_seq;

    super.body();

    m_seq = axis_cdv_m_basic_seq::type_id::create("m_seq");
    s_seq = axis_cdv_s_basic_seq::type_id::create("s_seq");

    // BFM 리셋 해제 대기
    if (m_cfg.m_axis_agent_cfg.drv_m_bfm.aresetn !== 1'b1) begin
      m_cfg.m_axis_agent_cfg.drv_m_bfm.wait_for_reset();
    end
    @(posedge m_cfg.m_axis_agent_cfg.drv_m_bfm.aclk);

    if (!m_seq.randomize()) `uvm_fatal("VSEQ", "m_seq randomize failed")
    if (!s_seq.randomize() with {num_trans == m_seq.num_trans;}) begin
      `uvm_fatal("VSEQ", "s_seq randomize failed")
    end

    // Master 송신과 Slave 수신(배압)을 동시에 구동
    fork
      begin
        m_seq.start(m_sqr);
      end
      begin
        s_seq.start(s_sqr);
      end
    join
  endtask
endclass

```