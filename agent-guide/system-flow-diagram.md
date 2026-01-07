# FPGA-i.MX8MP 시스템 동작 플로우

## 1. 전체 시스템 아키텍처

```mermaid
graph LR
    A[FPGA<br/>16-bit Data] --> B[Data Packing<br/>16bit→8bit]
    B --> C[MIPI CSI-2 TX<br/>FSM]
    C --> D[D-PHY TX<br/>4-Lane]
    D --> E[D-PHY RX<br/>4-Lane]
    E --> F[MIPI CSI-2 RX<br/>Bridge]
    F --> G[ISI<br/>Image Sensor Interface]
    G --> H[DRAM<br/>Memory]
    
    style A fill:#e1f5ff
    style B fill:#e1f5ff
    style C fill:#e1f5ff
    style D fill:#fff4e1
    style E fill:#ffe1e1
    style F fill:#ffe1e1
    style G fill:#ffe1e1
    style H fill:#ffe1e1
```

**범례**:
- 🔵 파란색: FPGA 영역
- 🟡 노란색: 물리 계층 (D-PHY)
- 🔴 빨간색: i.MX8MP 영역

---

## 2. 데이터 변환 플로우

```mermaid
flowchart TB
    Start[시작: 256개 16-bit 데이터] --> Pack[데이터 패킹]
    Pack --> |Little Endian| Raw8[512 bytes RAW8]
    
    Raw8 --> Check{메모리 정렬<br/>512 % 64 == 0?}
    Check -->|Yes ✅| AXI[AXI4-Stream<br/>변환]
    Check -->|No ❌| Error[정렬 에러]
    
    AXI --> TVALID{TVALID &&<br/>TREADY?}
    TVALID -->|Yes| TX[MIPI TX]
    TVALID -->|No| Wait[대기]
    Wait --> TVALID
    
    TX --> End[전송 완료]
    
    style Start fill:#e1f5ff
    style Pack fill:#e1f5ff
    style Raw8 fill:#e1ffe1
    style Check fill:#fff4e1
    style Error fill:#ffe1e1
    style AXI fill:#e1f5ff
    style TX fill:#e1f5ff
```

---

## 3. MIPI 프레임 전송 시퀀스

```mermaid
sequenceDiagram
    participant F as FPGA<br/>MIPI TX
    participant P as D-PHY<br/>4-Lane
    participant I as i.MX8MP<br/>ISI
    
    Note over F: 초기화
    F->>P: LP-11 (초기 상태)
    F->>P: HS Request
    P->>I: HS-0 (동기)
    
    Note over F,I: Frame Start
    F->>P: FS Packet (0x00)
    P->>I: FS Packet
    
    loop 16번 라인 반복
        Note over F: Line Start
        F->>P: LS Packet (0x02)
        P->>I: LS Packet
        
        Note over F: Payload 전송
        F->>P: 512 bytes RAW8
        P->>I: 512 bytes RAW8
        I->>I: 메모리 저장<br/>(DRAM)
    end
    
    Note over F,I: Frame End
    F->>P: FE Packet (0x01)
    P->>I: FE Packet
    
    Note over I: 프레임 완료
    I-->>F: (Backpressure if needed)
```

---

## 4. FPGA 내부 FSM 상태 다이어그램

```mermaid
stateDiagram-v2
    [*] --> IDLE: Reset
    IDLE --> FS: Frame Start 트리거
    FS --> LS: FS 패킷 전송 완료
    LS --> PAYLOAD: LS 패킷 전송 완료
    PAYLOAD --> BLANKING: 512 bytes 전송 완료<br/>(TLAST=1)
    BLANKING --> LS: 다음 라인<br/>(Line < 16)
    BLANKING --> FE: 마지막 라인<br/>(Line == 16)
    FE --> IDLE: FE 패킷 전송 완료
    
    note right of IDLE
        대기 상태
        TVALID = 0
    end note
    
    note right of FS
        Frame Start
        Data ID = 0x00
        TUSER[0] = 1
    end note
    
    note right of PAYLOAD
        데이터 전송
        TVALID = 1
        TREADY 확인
    end note
    
    note right of BLANKING
        Line 간 간격
        최소 10 cycles
    end note
```

---

## 5. i.MX8MP 데이터 처리 플로우

```mermaid
flowchart TB
    RX[MIPI CSI-2 RX] --> Parse[패킷 파싱]
    Parse --> FSCheck{FS 패킷?}
    
    FSCheck -->|Yes| NewFrame[새 프레임 시작]
    FSCheck -->|No| LSCheck{LS 패킷?}
    
    LSCheck -->|Yes| NewLine[새 라인 시작<br/>Line Count++]
    LSCheck -->|No| PayloadCheck{Payload?}
    
    PayloadCheck -->|Yes| WriteRAM[DRAM 쓰기<br/>Stride=512]
    PayloadCheck -->|No| FECheck{FE 패킷?}
    
    FECheck -->|Yes| Complete[프레임 완료<br/>v4l2 버퍼 준비]
    FECheck -->|No| Error[패킷 에러]
    
    WriteRAM --> Align{64-byte<br/>정렬?}
    Align -->|Yes ✅| Continue[계속]
    Align -->|No ❌| AlignError[정렬 에러]
    
    Continue --> LSCheck
    NewLine --> PayloadCheck
    NewFrame --> LSCheck
    Complete --> Done[캡처 완료]
    
    style RX fill:#ffe1e1
    style WriteRAM fill:#e1ffe1
    style Align fill:#fff4e1
    style Complete fill:#e1f5ff
    style Error fill:#ff9999
    style AlignError fill:#ff9999
```

---

## 6. AXI4-Stream Handshake 타이밍

```mermaid
sequenceDiagram
    participant M as Master<br/>(FPGA)
    participant S as Slave<br/>(MIPI IP)
    
    Note over M,S: 정상 전송
    M->>S: TVALID=1, TDATA=0xCD
    S->>M: TREADY=1
    Note over M,S: 데이터 전송 ✅
    
    M->>S: TVALID=1, TDATA=0xAB
    S->>M: TREADY=1
    Note over M,S: 데이터 전송 ✅
    
    Note over M,S: Backpressure 발생
    M->>S: TVALID=1, TDATA=0x12
    S->>M: TREADY=0
    Note over M,S: 데이터 대기 ⏸️
    
    M->>S: TVALID=1, TDATA=0x12 (유지)
    S->>M: TREADY=0
    Note over M,S: 계속 대기 ⏸️
    
    M->>S: TVALID=1, TDATA=0x12 (유지)
    S->>M: TREADY=1
    Note over M,S: 데이터 전송 ✅
```

---

## 7. 메모리 맵 및 데이터 복원

```mermaid
graph TB
    subgraph FPGA["FPGA 송신"]
        A1["Data[0] = 0xABCD"]
        A2["Data[1] = 0x1234"]
        A1 --> B1["Byte 0: 0xCD"]
        A1 --> B2["Byte 1: 0xAB"]
        A2 --> B3["Byte 2: 0x34"]
        A2 --> B4["Byte 3: 0x12"]
    end
    
    subgraph MIPI["MIPI 전송"]
        B1 --> C1[RAW8 Stream]
        B2 --> C1
        B3 --> C1
        B4 --> C1
    end
    
    subgraph iMX8MP["i.MX8MP 수신"]
        C1 --> D1["메모리<br/>Offset 0: 0xCD"]
        C1 --> D2["메모리<br/>Offset 1: 0xAB"]
        C1 --> D3["메모리<br/>Offset 2: 0x34"]
        C1 --> D4["메모리<br/>Offset 3: 0x12"]
    end
    
    subgraph Restore["복원 (Python)"]
        D1 --> E1["Data[0] = (0xAB << 8) | 0xCD"]
        D2 --> E1
        D3 --> E2["Data[1] = (0x12 << 8) | 0x34"]
        D4 --> E2
        E1 --> F1["0xABCD ✅"]
        E2 --> F2["0x1234 ✅"]
    end
    
    style FPGA fill:#e1f5ff
    style MIPI fill:#fff4e1
    style iMX8MP fill:#ffe1e1
    style Restore fill:#e1ffe1
```

---

## 8. 에러 처리 플로우

```mermaid
flowchart TB
    Start[시스템 시작] --> Check1{/dev/video0<br/>존재?}
    
    Check1 -->|No| Load[modprobe imx8-isi-cap]
    Load --> Check1
    Check1 -->|Yes| Check2{MIPI 데이터<br/>수신?}
    
    Check2 -->|No| Debug1[ILA로 FPGA 출력 확인]
    Debug1 --> Fix1[D-PHY 초기화 재점검]
    Fix1 --> Check2
    
    Check2 -->|Yes| Capture[v4l2-ctl 캡처]
    Capture --> Check3{파일 크기<br/>8192 bytes?}
    
    Check3 -->|No| Debug2[dmesg 로그 확인]
    Debug2 --> Fix2[Stride 재설정<br/>또는 라인 수 확인]
    Fix2 --> Capture
    
    Check3 -->|Yes| Verify[데이터 검증]
    Verify --> Check4{무결성<br/>100%?}
    
    Check4 -->|No| Debug3[Endian 확인]
    Debug3 --> Fix3[Byte Order 수정]
    Fix3 --> Capture
    
    Check4 -->|Yes| Success[검증 완료 ✅]
    
    style Start fill:#e1f5ff
    style Success fill:#e1ffe1
    style Debug1 fill:#fff4e1
    style Debug2 fill:#fff4e1
    style Debug3 fill:#fff4e1
    style Fix1 fill:#ffe1e1
    style Fix2 fill:#ffe1e1
    style Fix3 fill:#ffe1e1
```

---

## 9. 5일 작업 플로우 간트 차트

```mermaid
gantt
    title 5일 집중 작업 일정
    dateFormat YYYY-MM-DD
    
    section Day 1
    데이터 변환 규칙 정의           :d1t1, 2026-01-07, 4h
    ISI 메모리 맵 분석             :d1t2, 2026-01-07, 4h
    상호 검증                      :d1t3, after d1t2, 2h
    
    section Day 2
    16to8 변환 모듈                :d2t1, 2026-01-08, 5h
    Device Tree 작성               :d2t2, 2026-01-08, 3h
    자가 검토                      :d2t3, after d2t2, 2h
    
    section Day 3
    MIPI FSM 구현                  :d3t1, 2026-01-09, 4h
    가상 프레임 생성               :d3t2, after d3t1, 3h
    ISI 드라이버 설정              :d3t3, 2026-01-09, 3h
    
    section Day 4
    Vivado IP 설정 & 빌드          :d4t1, 2026-01-10, 5h
    커널 컴파일 & 배포             :d4t2, 2026-01-10, 4h
    예외 처리 검토                 :d4t3, after d4t2, 1h
    
    section Day 5
    데이터 캡처                    :d5t1, 2026-01-11, 2h
    무결성 검증                    :d5t2, after d5t1, 3h
    성능 측정 & 보고서             :d5t3, after d5t2, 3h
```

---

## 10. 시스템 상태 다이어그램 (전체)

```mermaid
stateDiagram-v2
    [*] --> SystemInit: Power On
    
    SystemInit --> KernelBoot: i.MX8MP 부팅
    KernelBoot --> FPGAConfig: SPI를 통한 FPGA Config
    FPGAConfig --> CheckDone: FPGA DONE 확인
    CheckDone --> DriverLoad: Config 완료
    CheckDone --> FPGAConfig: 재시도 (if not done)
    
    DriverLoad --> Ready: /dev/video0 생성
    
    Ready --> Capturing: v4l2-ctl 시작
    Capturing --> DataTX: FPGA 데이터 전송
    
    DataTX --> ISIWrite: ISI 메모리 쓰기
    ISIWrite --> BufferFull: 프레임 완료
    BufferFull --> Captured: 버퍼 준비
    
    Captured --> Ready: 다음 프레임
    Captured --> Verify: 검증 시작
    
    Verify --> Pass: 무결성 OK
    Verify --> Fail: 데이터 불일치
    
    Fail --> Debug: 디버깅
    Debug --> Ready: 재시도
    
    Pass --> [*]: 작업 완료
    
    note right of CheckDone
        FPGA DONE 핀 확인
        또는 상태 레지스터 체크
        Config 완료 후 진행
    end note
    
    note right of Ready
        시스템 대기
        캡처 준비됨
    end note
    
    note right of DataTX
        MIPI CSI-2
        4-Lane 전송
    end note
    
    note right of Verify
        Python 스크립트
        바이트 단위 비교
    end note
```

---

## 차트 활용 가이드

### VS Code에서 Mermaid 미리보기
1. **Markdown Preview Mermaid Support** 확장 설치
2. `Ctrl+Shift+V`로 미리보기 열기

### GitHub에서 자동 렌더링
- GitHub는 Mermaid를 기본 지원하므로 자동으로 다이어그램 표시

### 온라인 에디터
- https://mermaid.live/ 에서 실시간 편집 및 미리보기
