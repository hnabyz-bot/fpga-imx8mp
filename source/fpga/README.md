# FPGA Source Code

FPGA(Xilinx Artix-7 XC7A35T) 관련 소스 코드 및 IP 설정

---

## 🔄 FPGA 개발 워크플로우

```mermaid
graph TB
    Start([시작: FPGA Configuration 확인]) --> Config{DONE 신호 확인?}
    Config -->|No| Wait[대기 또는 재시도]
    Wait --> Config
    Config -->|Yes| IPSetup[1. MIPI TX IP 설정]
    
    IPSetup --> RTL1[2. 데이터 패킹 모듈]
    RTL1 --> Sim1{시뮬레이션 통과?}
    Sim1 -->|No| Debug1[디버깅: tb_data_pack.v]
    Debug1 --> RTL1
    Sim1 -->|Yes| RTL2[3. MIPI FSM]
    
    RTL2 --> Sim2{시뮬레이션 통과?}
    Sim2 -->|No| Debug2[디버깅: tb_fsm.v]
    Debug2 --> RTL2
    Sim2 -->|Yes| RTL3[4. 프레임 생성]
    
    RTL3 --> Top[5. Top 통합]
    Top --> Const[6. 제약 설정]
    
    Const --> Synth[7. 합성 & 구현]
    Synth --> TimingCheck{타이밍 충족?}
    TimingCheck -->|No| OptConst[제약 최적화]
    OptConst --> Const
    TimingCheck -->|Yes| BitGen[8. 비트스트림 생성]
    
    BitGen --> ILA[9. ILA 신호 검증]
    ILA --> Verify{신호 정상?}
    Verify -->|No| DebugRTL[RTL 수정]
    DebugRTL --> RTL2
    Verify -->|Yes| Done([완료: Integration 준비])
    
    style Start fill:#e1f5ff
    style Done fill:#e1ffe1
    style Config fill:#fff4e1
    style Sim1 fill:#fff4e1
    style Sim2 fill:#fff4e1
    style TimingCheck fill:#fff4e1
    style Verify fill:#fff4e1
```

---

## 🔧 모듈별 개발 플로우

### RTL 개발 단계

```mermaid
sequenceDiagram
    participant Dev as 개발자
    participant RTL as RTL 코드
    participant TB as 테스트벤치
    participant Sim as 시뮬레이터
    participant ILA as ILA
    
    Dev->>RTL: 1. 모듈 작성
    Dev->>TB: 2. 테스트벤치 작성
    Dev->>Sim: 3. 시뮬레이션 실행
    
    alt 시뮬레이션 실패
        Sim-->>Dev: 에러 발견
        Dev->>RTL: 4a. 코드 수정
        Dev->>Sim: 재시뮬레이션
    else 시뮬레이션 성공
        Sim-->>Dev: 통과 ✅
        Dev->>RTL: 4b. 합성
    end
    
    Dev->>ILA: 5. 하드웨어 검증
    
    alt 신호 이상
        ILA-->>Dev: 타이밍 문제 발견
        Dev->>RTL: 6a. 최적화
    else 신호 정상
        ILA-->>Dev: 검증 완료 ✅
    end
```

### 빌드 플로우

```mermaid
flowchart LR
    A[RTL 소스] --> B[Synthesis]
    B --> C{Setup/Hold 위반?}
    C -->|Yes| D[제약 수정]
    D --> B
    C -->|No| E[Implementation]
    E --> F{Timing 충족?}
    F -->|No| G[로직 최적화]
    G --> E
    F -->|Yes| H[Bitstream 생성]
    H --> I[.bit 파일]
    
    style I fill:#e1ffe1
    style C fill:#fff4e1
    style F fill:#fff4e1
```

---

## 📁 폴더 구조

```
fpga/
├── rtl/          Verilog/VHDL RTL 코드
├── ip/           Vivado IP 설정 파일 (TCL 스크립트)
├── constraints/  제약 파일 (XDC)
└── sim/          테스트벤치 및 시뮬레이션
```

## 📝 주요 모듈

### rtl/
- `data_pack_16to8.v` - 16-bit → 8-bit 데이터 패킹 모듈
- `mipi_csi2_tx_fsm.v` - MIPI CSI-2 TX FSM
- `frame_generator.v` - 가상 프레임 생성 (16줄 반복)
- `top.v` - Top 모듈

### ip/
- `mipi_csi2_tx_setup.tcl` - MIPI CSI-2 TX Subsystem IP 설정

### constraints/
- `pins.xdc` - 핀 맵핑
- `timing.xdc` - 타이밍 제약

### sim/
- `tb_data_pack.v` - 데이터 패킹 테스트벤치
- `tb_fsm.v` - FSM 테스트벤치

---

## 📋 체크리스트

### IP 설정 (ip/)
- [ ] MIPI CSI-2 TX Subsystem IP 추가
- [ ] 4-Lane, RAW8 (0x2A) 설정
- [ ] D-PHY 타이밍 파라미터 설정
- [ ] Virtual Channel = 0

### RTL 개발 (rtl/)
- [ ] data_pack_16to8.v - Little Endian 변환
- [ ] mipi_csi2_tx_fsm.v - FS/LS/Payload/FE
- [ ] frame_generator.v - 16줄 반복
- [ ] top.v - 통합 모듈

### 제약 (constraints/)
- [ ] pins.xdc - 핀 맵핑 (MIPI, Clock)
- [ ] timing.xdc - 타이밍 제약

### 시뮬레이션 (sim/)
- [ ] tb_data_pack.v - Endian 검증
- [ ] tb_fsm.v - MIPI 패킷 검증
- [ ] 모든 테스트 통과

### 검증
- [ ] ILA로 신호 확인 (TVALID, TREADY, TLAST)
- [ ] 타이밍 에러 없음
- [ ] 리소스 사용률 < 80%

---

## 🐛 자주 발생하는 이슈

| 문제 | 원인 | 해결 |
|------|------|------|
| Setup 위반 | 클럭 주파수 너무 높음 | 클럭 낮추기 또는 파이프라인 추가 |
| FIFO Overflow | Backpressure 미처리 | TREADY 신호 처리 로직 추가 |
| 시뮬레이션 실패 | Endian 변환 오류 | 바이트 순서 재확인 |
| ILA 신호 없음 | Clock 미연결 | 클럭 트리 확인 |

---

## 🎯 개발 가이드

**상세 Task 가이드**: [../../agent-guide/agent-prompts.md](../../agent-guide/agent-prompts.md)  
**5일 계획**: [../../agent-guide/todo-list-5days.md](../../agent-guide/todo-list-5days.md)
