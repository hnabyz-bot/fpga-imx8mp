# Source Code Directory

실제 구현 코드를 위한 디렉토리

---

## 🔄 전체 개발 통합 플로우

```mermaid
graph TB
    Start([프로젝트 시작]) --> Plan[문서 검토]
    
    Plan --> Parallel{병렬 개발}
    
    Parallel -->|FPGA 팀| FPGA1[FPGA 개발]
    Parallel -->|i.MX8MP 팀| IMX1[i.MX8MP 개발]
    
    FPGA1 --> FPGA2[IP 설정]
    FPGA2 --> FPGA3[RTL 개발]
    FPGA3 --> FPGA4[시뮬레이션]
    FPGA4 --> FPGA5[합성 & 구현]
    FPGA5 --> FPGA6[비트스트림]
    FPGA6 --> FPGAReady{FPGA 완료?}
    
    IMX1 --> IMX2[Device Tree]
    IMX2 --> IMX3[DT 컴파일]
    IMX3 --> IMX4[커널 배포]
    IMX4 --> IMX5[드라이버 확인]
    IMX5 --> IMX6[스크립트 작성]
    IMX6 --> IMXReady{i.MX8MP 완료?}
    
    FPGAReady -->|Yes| Integration[통합 테스트]
    IMXReady -->|Yes| Integration
    
    Integration --> Test1[1. FPGA Config 확인]
    Test1 --> Test2[2. MIPI 연결 확인]
    Test2 --> Test3[3. 데이터 캡처]
    Test3 --> Test4[4. 무결성 검증]
    
    Test4 --> Final{검증 통과?}
    Final -->|No| Debug{문제 영역?}
    Debug -->|FPGA| FPGA3
    Debug -->|i.MX8MP| IMX2
    Debug -->|둘 다| Integration
    
    Final -->|Yes| Complete([프로젝트 완료 🎉])
    
    style Start fill:#e1f5ff
    style Complete fill:#e1ffe1
    style Parallel fill:#fff4e1
    style FPGAReady fill:#fff4e1
    style IMXReady fill:#fff4e1
    style Final fill:#fff4e1
    style Debug fill:#ffe1e1
```

---

## 🎯 팀별 작업 흐름

### FPGA 팀 (Day 1-4)

```mermaid
gantt
    title FPGA 개발 일정
    dateFormat YYYY-MM-DD
    
    section Setup
    IP 설정           :a1, 2026-01-07, 1d
    
    section RTL
    데이터 패킹       :a2, after a1, 1d
    MIPI FSM          :a3, after a2, 1d
    프레임 생성       :a4, after a3, 1d
    
    section 통합
    Top 모듈          :a5, after a4, 1d
    제약 설정         :a6, after a5, 1d
    
    section 검증
    합성 & 구현       :a7, after a6, 1d
    ILA 검증          :a8, after a7, 1d
```

### i.MX8MP 팀 (Day 1-4)

```mermaid
gantt
    title i.MX8MP 개발 일정
    dateFormat YYYY-MM-DD
    
    section 분석
    사양 확정         :b1, 2026-01-07, 1d
    
    section DT
    Device Tree 작성  :b2, after b1, 1d
    DT 컴파일         :b3, after b2, 1d
    
    section 배포
    커널 배포         :b4, after b3, 1d
    드라이버 확인     :b5, after b4, 1d
    
    section 스크립트
    캡처 스크립트     :b6, after b5, 1d
    검증 스크립트     :b7, after b6, 1d
```

---

## 🔍 통합 테스트 플로우

```mermaid
sequenceDiagram
    participant User as 테스트 담당자
    participant FPGA as FPGA
    participant PHY as MIPI D-PHY
    participant IMX as i.MX8MP
    participant Script as 검증 스크립트
    
    Note over User: Day 5: 통합 테스트
    
    User->>FPGA: 1. DONE 상태 확인
    FPGA-->>User: DONE = High ✅
    
    User->>IMX: 2. 드라이버 확인
    IMX-->>User: /dev/video0 존재 ✅
    
    User->>FPGA: 3. 데이터 전송 시작
    FPGA->>PHY: MIPI 패킷 (FS→LS→Payload→FE)
    PHY->>IMX: 4-Lane 전송
    IMX->>IMX: ISI → DRAM 저장
    
    User->>IMX: 4. v4l2-ctl 캡처
    IMX-->>User: capture.raw (8192 bytes)
    
    User->>Script: 5. verify.py 실행
    Script->>Script: RAW8 → 16-bit 복원
    Script->>Script: 데이터 비교
    
    alt 데이터 불일치
        Script-->>User: 오프셋: 1024, 기대: 0xABCD, 실제: 0xABDC
        User->>FPGA: Endian 확인
        User->>IMX: 복원 로직 확인
    else 데이터 일치
        Script-->>User: 무결성 100% ✅
        Note over User: 프로젝트 완료!
    end
```

---

## 📁 구조

```
source/
├── fpga/         FPGA (Xilinx Artix-7) 관련 코드
│   ├── rtl/      Verilog/VHDL RTL
│   ├── ip/       Vivado IP 설정
│   ├── constraints/ XDC 제약 파일
│   └── sim/      테스트벤치
│
└── imx8mp/       i.MX8MP 관련 코드
    ├── device-tree/ Device Tree 설정
    ├── scripts/  스크립트 (캡처, 검증)
    └── drivers/  드라이버 (필요 시)
```

---

## 📋 통합 체크리스트

### 사전 준비
- [ ] FPGA 비트스트림 준비 (.bit)
- [ ] i.MX8MP 커널 이미지 준비
- [ ] Device Tree Blob 준비 (.dtb)
- [ ] 검증 스크립트 준비 (capture.sh, verify.py)

### 하드웨어 연결
- [ ] FPGA ↔ i.MX8MP MIPI 연결
- [ ] SPI 연결 (Config용)
- [ ] 전원 및 Clock 연결
- [ ] UART 디버그 연결

### FPGA 측
- [ ] FPGA Configuration 완료
- [ ] DONE 신호 확인
- [ ] ILA 신호 확인 (TVALID, TREADY, TLAST)
- [ ] MIPI 패킷 출력 확인

### i.MX8MP 측
- [ ] 커널 부팅 성공
- [ ] /dev/video0 생성 확인
- [ ] ISI clock 활성화
- [ ] dmesg 에러 없음

### 데이터 검증
- [ ] 파일 크기: 8192 bytes
- [ ] 데이터 무결성: 100%
- [ ] 연속 캡처 성공 (10회 이상)
- [ ] MIPI PHY 에러: 0건

---

## 🚨 통합 테스트 시 주의사항

### FPGA
1. **Configuration 순서 엄수**: i.MX8MP SPI → FPGA Config → DONE 확인
2. **타이밍 검증**: ILA로 AXI Handshake 확인 필수
3. **Clock 안정화**: 최소 10ms 대기 후 데이터 전송

### i.MX8MP
1. **드라이버 로드 확인**: 매 부팅 시 `lsmod` 확인
2. **ISI 초기화**: setup_isi.sh 실행 필수
3. **메모리 정렬**: stride = 512, 64-byte 정렬 재확인

### 통합
1. **점진적 테스트**: 한 프레임씩 확인 후 연속 테스트
2. **로그 수집**: dmesg, ILA 로그 저장
3. **재현성 확보**: 실패 시 재현 가능하도록 조건 기록

---

## 🚀 시작하기

### FPGA 개발
1. [fpga/README.md](fpga/README.md) 참조
2. Task 가이드: [../agent-guide/agent-prompts.md](../agent-guide/agent-prompts.md)
3. 5일 계획: [../agent-guide/todo-list-5days.md](../agent-guide/todo-list-5days.md)

### i.MX8MP 개발
1. [imx8mp/README.md](imx8mp/README.md) 참조
2. Device Tree 가이드: [../agent-guide/agent-prompts.md](../agent-guide/agent-prompts.md)

---

## 📚 참고 문서

**프로젝트 문서**: [../agent-guide/](../agent-guide/) 폴더  
**FPGA 상세**: [fpga/README.md](fpga/README.md)  
**i.MX8MP 상세**: [imx8mp/README.md](imx8mp/README.md)
