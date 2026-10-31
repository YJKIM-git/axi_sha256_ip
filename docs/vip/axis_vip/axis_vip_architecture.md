# AXI4-Stream UVM VIP Architecture & Developer Reference

본 문서는 VIP 유지보수 및 확장을 담당하는 엔지니어를 위한 아키텍처 및 내부 구조 명세서입니다.

## 1. Architectural Overview

본 VIP는 확장성과 재사용성을 극대화하기 위해 Siemens Verification Academy의 `apb_agent` 구조를 벤치마킹하여 설계되었습니다. 클래스 기반의 UVM 컴포넌트와 물리적 핀 레벨 제어를 담당하는 BFM(Bus Functional Model)을 엄격히 분리한 **Dual-Top 구조**를 채택하였습니다.
단일 `axis_agent` 내부에 Master와 Slave 컴포넌트가 모두 구현되어 있으며, 런타임 시 `axis_agent_config`의 설정(`is_master`)에 따라 내부 토폴로지가 동적으로 구성됩니다.

### 1.1. Master Mode Topology (`is_master = 1`)

Master 모드에서는 `axis_m_driver`와 `axis_m_driver_bfm`이 활성화되어 시퀀스로부터 전달받은 패킷 데이터를 AXI4-Stream 버스에 인가합니다.

```bash
+----------------------------------------------------+
|  Sequence Library                                  |
|  * Master: axis_m_*_seq                            |
+----------------------------------------------------+
             |
             v (axis_seq_item)
+====================================================+
|                                axis_agent          |
|                                                    |
|  +----------------+     +-------------------+      |
|  | axis_sequencer |===> |   axis_m_driver   |      |
|  +----------------+     +-------------------+      |
|                                   | (Task Call)    |
|  +----------------+     +-------------------+      |
|  | axis_coverage  |<--ap|   axis_monitor    |      |
|  +----------------+     +-------------------+      |
|            |                      ^ (Event/Data)   |
+============|======================|================+
             v (To Env)             |
                                    |
+-----------------------------------|----------------+
|            Virtual Interface Layer (BFM & IF)      |
|                               |                    |
|             +-------------------+                  |
|             | axis_m_driver_bfm | <---+            |
|             +-------------------+     |            |
|                       | (Drive)       |            |
|                       v               |            |
|             +-------------------+     |            |
|      DUT <==|      axis_if      |==> SVA           |
|             +-------------------+     |            |
|                       | (Sample)      |            |
|                       v               |            |
|             +-------------------+     |            |
|             | axis_monitor_bfm  |-----+            |
|             +-------------------+                  |
+----------------------------------------------------+

```

### 1.2. Slave Mode Topology (`is_master = 0`)

Slave 모드에서는 `axis_s_driver`와 `axis_s_driver_bfm`이 활성화되어, 수신 측의 배압(Back-pressure, TREADY 딜레이) 조건 및 핸드셰이크를 제어합니다.

```bash
+--------------------------------------------------+
|  Sequence Library                                |
|  * Slave: axis_s_*_seq                           |
+--------------------------------------------------+
            |
            v (axis_seq_item)
+==================================================+
|                                axis_agent        |
|                                                  |
|  +----------------+     +-------------------+    |
|  | axis_sequencer |===> |   axis_s_driver   |    |
|  +----------------+     +-------------------+    |
|                                   | (Task Call)  |
|  +----------------+     +-------------------+    |
|  | axis_coverage  |<--ap|   axis_monitor    |    |
|  +----------------+     +-------------------+    |
|            |                      ^ (Event/Data) |
+============|======================|==============+
             v (To Env)             |
                                    |
+-----------------------------------|--------------+
|                Virtual Interface Layer (BFM & IF)|
|                                   |              |
|                 +-------------------+            |
|                 | axis_s_driver_bfm | <---+      |
|                 +-------------------+     |      |
|                           | (Drive)       |      |
|                           v               |      |
|                 +-------------------+     |      |
|          DUT ==>|      axis_if      |==> SVA     |
|                 +-------------------+     |      |
|                           | (Sample)      |      |
|                           v               |      |
|                 +-------------------+     |      |
|                 | axis_monitor_bfm  |-----+      |
|                 +-------------------+            |
+--------------------------------------------------+

```
## 2. UVM Components & Data Structure

### 2.1. Agent Configuration & Dynamic Topology
`axis_agent`는 `build_phase`에서 `axis_agent_config`를 로드하고, 설정에 따라 내부 컴포넌트와 물리 BFM을 유연하게 구성합니다.

* `is_active = UVM_ACTIVE`인 경우 Sequencer와 Driver를 생성합니다.
* `is_master = 1`인 경우 `axis_m_driver` 및 `axis_m_driver_bfm`을 연결하여 `TVALID`를 포함한 송신 채널을 제어합니다.
* `is_master = 0`인 경우 `axis_s_driver` 및 `axis_s_driver_bfm`을 연결하여 `TREADY` 신호를 통한 배압(Back-pressure)을 제어합니다.
* 다중 패킷(Multiple TID) 동시 전송 시, `arb_mode` 설정을 통해 Round-Robin(`ARB_RR`) 또는 Random(`ARB_RANDOM`) 중재 방식을 선택할 수 있습니다.
* AXI4-Stream 인터페이스의 물리적 신호 폭은 코드 수정 없이 다양한 DUT 스펙을 수용할 수 있도록 넓게 고정되어 있습니다.

```text
TDATA : 1024-bit
TKEEP : 128-bit (1024/8)
TSTRB : 128-bit (1024/8)
TUSER : 1024-bit
TID   : 32-bit
TDEST : 32-bit

```

`axis_agent_config` 내의 `active_data_width`, `active_user_width` 파라미터는 이 물리적 폭을 변경하는 것이 아니라, 현재 검증 시나리오에서 유효하게 쓰일 논리적 폭(Logical Width)과 값의 범위를 지정하는 런타임 제어 변수입니다. 단, `active_data_width = 0` 설정은 프로토콜 검증 및 커버리지 대상에서 제외되며, 현재 Config 계층에서 `UVM_FATAL` 등을 통한 명시적인 차단(Validation)은 제공하지 않습니다.


### 2.2. Sequence Item Static Allocation (`axis_seq_item`)

`axis_seq_item`은 최대 물리 폭을 기준으로 스트림 패킷(Packet)을 표현하며, 내부적으로 데이터를 Queue(큐) 형태로 관리합니다.

* `tdata_q[$]`, `tstrb_q[$]`, `tkeep_q[$]`, `tuser_q[$]`는 Beat 단위의 데이터를 담는 Queue입니다.
* 패킷의 무결성을 위해 데이터, Qualifier(TSTRB/TKEEP), 딜레이 Queue의 크기는 항상 동일해야 합니다.
* `valid_delay_q`와 `ready_delay_q`는 각 Beat별 VALID 및 READY 지연(Wait states)을 독립적으로 제어합니다.
* 기본 패킷 길이는 1~64 Beat 범위로 설정되어 있으나(`soft` 제약 조건), 사용자가 시퀀스 단에서 자유롭게 오버라이드할 수 있습니다.

앞서 설정된 논리적 폭은 `axis_seq_item::post_randomize()` 단계에서 1024-bit 물리 폭 데이터에 마스킹 처리됩니다. 이를 통해 트랜잭션 아이템의 컨테이너 크기는 고정하되, 유효 데이터와 스트로브 영역만 동적으로 제한하여 클래스 파편화를 방지합니다.

### 2.3. Driver, Monitor & Analysis Flow

**Master / Slave Driver Flow:**

* Master 시퀀스는 데이터 배열을 갖춘 아이템을 구동합니다. Master Driver BFM(`axis_m_driver_bfm`)은 전달받은 아이템을 파싱하여 TID별 내부 패킷 큐(`active_pkt_q`)에 보관하고, 설정된 Arbitration 정책에 따라 Beat를 물리 인터페이스에 순차적으로 인가합니다.
* Slave 모드 구동 시, Slave Driver BFM(`axis_s_driver_bfm`)은 아이템 내부에 정의된 `ready_delay_q` 값만을 추출하여 TREADY Back-pressure 타이밍을 설정합니다.

**Monitor Flow:**
Monitor BFM(`axis_monitor_bfm`)은 실제 핸드셰이크(TVALID && TREADY)가 발생한 Beat의 데이터를 샘플링하여 재조립합니다. 데이터는 TID별로 재조립되지만, 대기 시간(Delay Counter)은 현재 전역(Global) 상태로 추적됩니다. `TLAST`가 관찰되면 하나의 완전한 패킷으로 간주하고, `axis_monitor`의 Analysis Port를 통해 UVM 환경으로 브로드캐스트합니다.

패킷의 처리 상태는 `status` 변수를 통해 표현되며, 정상 `TLAST` 수신 시 `OK`, 시뮬레이션 중 리셋이 발생하여 잘린 패킷은 `INCOMPLETE`로 할당되어 스코어보드 오작동을 방지합니다. (`PROTOCOL_ERR` 상태는 열거형으로 정의되어 있으나, 현재 Monitor 수집 경로에서는 자동 할당되지 않습니다.)


## 3. BFM Layer Implementation

BFM 계층은 UVM component와 물리적 인터페이스 간의 신호 변환 및 샘플링을 수행합니다.

### 3.1. Master Driver BFM (`axis_m_driver_bfm`)

Master Driver BFM은 다중 패킷 전송 및 out-of-order 데이터 인가를 지원합니다.

* **Packet 관리:** 상위 sequence로부터 전달받은 packet은 `tid`를 key로 사용하는 associative array인 `active_pkt_q`에 저장됩니다.
* **Arbitration:** 대기 중인 여러 `tid`가 존재할 경우, `arb_mode`(`ARB_RR` 또는 `ARB_RANDOM`) 설정에 따라 다음 전송할 `tid`를 결정하여 interleaving을 지원합니다.
* **Timeout 및 Unknown 제어:** 구동 루프(`drive_bus`) 및 완료 대기 태스크(`wait_pkt_done`)에서 `tready` 신호가 `timeout_cycles`(기본 1000 사이클) 이상 비활성화되거나 Unknown(`1'bx`) 상태가 감지되면 즉시 `UVM_ERROR`를 발생시키고 해당 패킷을 큐에서 삭제하여 시뮬레이션 교착을 방지합니다.
* **Queue Flush (`flush`):** 하드웨어 리셋(`!aresetn`) 감지 시 `active_pkt_q`와 구동 상태 플래그를 즉시 초기화합니다.

### 3.2. Slave Driver BFM (`axis_s_driver_bfm`)

Slave Driver BFM은 인터페이스 수신 측의 back-pressure를 제어합니다.

* **Delay Queue 관리:** Sequence item의 `ready_delay_q` 값을 전달받아 내부 queue에 저장합니다.
* **TREADY 제어:** Queue에서 읽어온 delay 값만큼 대기한 후 `tready`를 High로 구동합니다.
* **Handshake 대기:** `tready`가 High인 상태에서 `tvalid` 수신 대기 시간이 `timeout_cycles`를 초과하면 상태를 초기화합니다.

### 3.3. Monitor BFM (`axis_monitor_bfm`)

Monitor BFM은 버스 상의 트랜잭션을 샘플링하여 재조립(Reassembly)한 후 상위 Monitor로 전달합니다.

* **Packet 생성 및 누적:** Handshake(`tvalid && tready`) 발생 시 데이터를 샘플링합니다. `tid`를 기준으로 `axis_seq_item`을 동적으로 생성하고 데이터를 누적합니다.
* **Delay 추적:** Handshake 이전의 `tvalid` Low 구간은 `ipg_cnt`로, `tready` Low 구간은 `r_delay_cnt`로 카운트하여 아이템에 기록합니다. 해당 카운터는 TID별 독립 변수가 아닌 단일 전역 변수로 관리되므로, 다중 TID 패킷이 혼재(Interleaving)할 경우 딜레이 값의 해석에 주의가 필요합니다.
* **Packet 종료 및 Flush:** `tlast` 신호가 High인 Beat를 샘플링하면 `status = OK`로 설정하여 등록된 Proxy(`axis_monitor`)로 복제본(Clone)을 전달한 뒤 내부 배열에서 삭제합니다. 패킷 전송 도중 하드웨어 리셋(`!aresetn`)이 인가되거나 `flush()` 태스크가 호출되면, 수집 중이던 미완성 패킷을 `status = INCOMPLETE`로 태깅하여 즉시 브로드캐스트하고 내부 큐와 카운터를 초기화합니다.

## 4. Interface & SVA (`axis_if`)

`axis_if`는 AXI4-Stream 프로토콜의 물리적 신호 연결을 담당하며, 내부적으로 검증을 위한 SVA를 포함합니다.

### 4.1. Interface Design

* **Over-provisioning 구조:** Interface 내부 parameter(`DataWidth`, `UserWidth` 등)는 1024-bit로 할당되어 있습니다. Target DUT 사양 변경 시 interface 코드를 수정하지 않고 `axis_agent_config`를 통한 mask 처리만으로 대응하기 위한 설계입니다.
* **Clocking Block 구성:** Master, Slave, Monitor 동작 모드에 따라 독립적인 clocking block(`dr_m_cb`, `dr_s_cb`, `mon_cb`)을 선언하여 사용합니다. 이를 통해 각 component가 신호를 drive 하거나 sample 할 때 일관된 timing을 유지합니다.

### 4.2. Supported ARM Assertions

내장된 SVA는 ARM 사의 공식 검증 가이드라인인 "AMBA 4 AXI4, AXI4-Lite, and AXI4-Stream Protocol Assertions User Guide"를 기준으로 설계되었으며, VIP 구현 환경에 맞춘 지원 및 배제(Waiver) 항목은 다음과 같습니다. 동일한 로직을 공유하는 신호는 macro(`ASSERT_STABLE`, `ASSERT_X_WHEN_VALID`, `ASSERT_X_NOT_IN_RESET`)를 통해 통합 구현되었습니다.

| Category | VIP Implemented SVA | ARM Official SVA List |
| --- | --- | --- |
| **Reset** | `p_err_tvalid_reset` | `AXI4STREAM_ERRM_TVALID_RESET` |
| **Stability** | `ASSERT_STABLE` | `AXI4STREAM_ERRM_TID_STABLE`, `AXI4STREAM_ERRM_TDEST_STABLE`, `AXI4STREAM_ERRM_TDATA_STABLE`, `AXI4STREAM_ERRM_TSTRB_STABLE`, `AXI4STREAM_ERRM_TLAST_STABLE`, `AXI4STREAM_ERRM_TKEEP_STABLE`, `AXI4STREAM_ERRM_TVALID_STABLE`, `AXI4STREAM_ERRM_TUSER_STABLE` |
| **Unknown Check (Valid)** | `ASSERT_X_WHEN_VALID` | `AXI4STREAM_ERRM_TID_X`, `AXI4STREAM_ERRM_TDEST_X`, `AXI4STREAM_ERRM_TDATA_X`, `AXI4STREAM_ERRM_TSTRB_X`, `AXI4STREAM_ERRM_TLAST_X`, `AXI4STREAM_ERRM_TKEEP_X` |
| **Unknown Check (Reset)** | `ASSERT_X_NOT_IN_RESET` | `AXI4STREAM_ERRM_TVALID_X`, `AXI4STREAM_ERRS_TREADY_X`, `AXI4STREAM_ERRM_TUSER_X` |
| **Strobe & Keep** | `p_err_tkeep_tstrb` | `AXI4STREAM_ERRM_TKEEP_TSTRB` |
| **Timeout** | `p_rec_tready_max_wait` | `AXI4STREAM_RECS_TREADY_MAX_WAIT` |

### 4.3. Unsupported Assertions

AXI4-Stream 스펙 중 본 VIP 구조상 인터페이스 계층(SVA)에서 지원하지 않거나 배제된 검증 항목입니다.

* **End of Simulation:** `AXI4STREAM_ERRM_STREAM_ALL_DONE_EOS`
* 사유: 시뮬레이션 종료 시점의 잔여 응답 여부는 하위 SVA가 아닌 상위 계층인 `axis_monitor`의 `check_phase`에서 검사하도록 위임되었습니다.


* **Tie-off 속성 미지원:** `AXI4STREAM_ERRM_TDATA_TIEOFF`, `AXI4STREAM_ERRM_TKEEP_TIEOFF`, `AXI4STREAM_ERRM_TSTRB_TIEOFF`, `AXI4STREAM_ERRM_TID_TIEOFF`, `AXI4STREAM_ERRM_TDEST_TIEOFF`, `AXI4STREAM_ERRM_TUSER_TIEOFF`
* 사유: 해당 규격은 특정 Width가 0인 상황을 위한 검증 항목입니다. 본 VIP는 Width 0 구성을 검증 대상으로 지원하지 않으므로 배제되었습니다.

## 5. Protocol Coverage (`axis_coverage.svh`)
커버리지 그룹은 데이터 폭과 채널 설정에 따라 정적(Static) 구조와 동적(Dynamic) 구조로 분리되어 할당됩니다.

* **Static Covergroup:** 컴포넌트 생성 시점에 고정 할당되며, 공통 프로토콜 타이밍(Handshake, Packet Boundary, Reset)을 측정합니다.
* **Dynamic Covergroup:** `axis_agent_config`의 논리 폭 설정(`active_data_width`, `active_user_width` 등)에 따라 동적으로 할당됩니다. 예를 들어, 데이터 폭이 8-bit 이하인 경우 `_no_partial` 그룹이 할당되어 불필요한 빈 생성을 억제합니다. 또한 데이터 무결성 검증 시 적용되는 `Toggle` 항목은 임의의 데이터 변화가 아닌 활성 폭 내 인접 비트가 상호 반전(Alternating)되는 특정 패턴을 의미하도록 엄격하게 정의되어 있습니다.

## 6. Design Considerations & Limitations

본 VIP는 경량화 및 실행 속도 최적화를 목적으로 아래의 기능은 지원하지 않습니다.

* **Data Width 0 미지원:** AXI4-Stream 스펙 상 존재하는 Data Width 0(Null 전송) 조건은 본 VIP 구조상 지원하지 않습니다. 이에 따라 관련된 Tie-off 검증 항목(`AXI4STREAM_ERRM_TDATA_TIEOFF` 등)은 배제되었습니다.