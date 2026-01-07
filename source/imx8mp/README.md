# i.MX8MP Source Code

i.MX8MP 관련 Device Tree, 스크립트, 드라이버

---

## 🔄 i.MX8MP 개발 워크플로우

```mermaid
graph TB
    Start([시작: FPGA Config 완료]) --> Check{FPGA DONE 확인?}
    Check -->|No| Script1[check_fpga_done.sh 작성]
    Script1 --> Check
    Check -->|Yes| DTS1[1. Device Tree 작성]
    
    DTS1 --> DTSDetail[mipi_csi, isi 노드 설정]
    DTSDetail --> DTSVerify{DTS 문법 검증?}
    DTSVerify -->|No| DTSFix[dtc로 검증]
    DTSFix --> DTS1
    DTSVerify -->|Yes| Compile[2. Device Tree 컴파일]
    
    Compile --> Deploy[3. 커널 배포]
    Deploy --> Boot[4. i.MX8MP 부팅]
    
    Boot --> DriverCheck{드라이버 로드?}
    DriverCheck -->|No| LoadDriver[modprobe imx8-isi-cap]
    LoadDriver --> DriverCheck
    DriverCheck -->|Yes| VideoCheck{/dev/video0 존재?}
    
    VideoCheck -->|No| Debug1[dmesg 확인]
    Debug1 --> DTS1
    VideoCheck -->|Yes| ISICheck[5. ISI 설정 확인]
    
    ISICheck --> ClockCheck{Clock 활성화?}
    ClockCheck -->|No| ClockFix[clk_summary 확인]
    ClockFix --> DTS1
    ClockCheck -->|Yes| Capture[6. 데이터 캡처]
    
    Capture --> Size{파일 크기 8192 bytes?}
    Size -->|No| Debug2[Height/Stride 확인]
    Debug2 --> DTS1
    Size -->|Yes| Verify[7. 데이터 검증]
    
    Verify --> Integrity{무결성 100%?}
    Integrity -->|No| Debug3[Endian 확인]
    Debug3 --> Verify
    Integrity -->|Yes| Done([완료: 통합 테스트 준비])
    
    style Start fill:#ffe1e1
    style Done fill:#e1ffe1
    style Check fill:#fff4e1
    style DTSVerify fill:#fff4e1
    style DriverCheck fill:#fff4e1
    style VideoCheck fill:#fff4e1
    style ClockCheck fill:#fff4e1
    style Size fill:#fff4e1
    style Integrity fill:#fff4e1
```

---

## 🔧 개발 상세 플로우

### Device Tree 작성 프로세스

```mermaid
sequenceDiagram
    participant Dev as 개발자
    participant DTS as .dts 파일
    participant DTC as DT Compiler
    participant Kernel as Kernel
    participant HW as Hardware
    
    Dev->>DTS: 1. mipi_csi 노드 작성
    Dev->>DTS: 2. isi 노드 작성
    Dev->>DTS: 3. 엔드포인트 연결
    
    Dev->>DTC: 4. 컴파일
    
    alt 컴파일 에러
        DTC-->>Dev: 문법 오류
        Dev->>DTS: 5a. 수정
        Dev->>DTC: 재컴파일
    else 컴파일 성공
        DTC-->>Dev: .dtb 생성 ✅
    end
    
    Dev->>Kernel: 6. 배포 및 부팅
    Kernel->>HW: 7. 하드웨어 초기화
    
    alt 초기화 실패
        HW-->>Dev: dmesg 에러
        Dev->>DTS: 8a. DT 수정
    else 초기화 성공
        HW-->>Dev: /dev/video0 생성 ✅
    end
```

### 캡처 및 검증 플로우

```mermaid
flowchart TB
    A[v4l2-ctl 캡처] --> B{파일 생성?}
    B -->|No| C[dmesg 확인]
    C --> D[드라이버/DT 점검]
    D --> A
    
    B -->|Yes| E[파일 크기 확인: 8192 bytes]
    E --> F{크기 정확?}
    F -->|No| G[Height/Stride 재설정]
    G --> A
    
    F -->|Yes| H[Python 검증: verify.py]
    H --> I[RAW8 to 16-bit Little Endian]
    I --> J{무결성 100%?}
    
    J -->|No| K[데이터 비교, 오프셋 확인]
    K --> L[FPGA 점검]
    
    J -->|Yes| M[검증 완료 ✅]
    
    style M fill:#e1ffe1
    style B fill:#fff4e1
    style F fill:#fff4e1
    style J fill:#fff4e1
```

---

## 📁 폴더 구조

```
imx8mp/
├── device-tree/  Device Tree Source 파일
├── scripts/      캡처 및 검증 스크립트
└── drivers/      커스텀 드라이버 (필요 시)
```

## 📝 주요 파일

### device-tree/
- `imx8mp-mipi-csi2.dts` - MIPI CSI-2 및 ISI 설정
- `imx8mp-overlay.dtso` - Device Tree Overlay

### scripts/
- `capture.sh` - v4l2-ctl 기반 데이터 캡처
- `verify.py` - 데이터 무결성 검증
- `check_fpga_done.sh` - FPGA Configuration 확인
- `setup_isi.sh` - ISI 초기화

### drivers/
- (필요 시 커스텀 드라이버 추가)

---

## 📋 체크리스트

### Device Tree (device-tree/)
- [ ] mipi_csi 노드 설정
  - [ ] data-lanes = <1 2 3 4>
  - [ ] clock-lanes = <0>
- [ ] isi 노드 설정
  - [ ] width = 512, height = 16
  - [ ] stride = 512 (64-byte 정렬)
  - [ ] ISP 우회 설정
- [ ] 엔드포인트 연결
- [ ] .dtb 컴파일 성공

### 스크립트 (scripts/)
- [ ] check_fpga_done.sh - DONE 확인
- [ ] setup_isi.sh - ISI 초기화
- [ ] capture.sh - v4l2-ctl 캡처
- [ ] verify.py - 데이터 검증
  - [ ] Little Endian 변환
  - [ ] 바이트 단위 비교

### 시스템 확인
- [ ] 드라이버 로드: `lsmod | grep imx8_isi`
- [ ] /dev/video0 생성
- [ ] ISI clock 활성화
- [ ] Power domain ON

### 검증
- [ ] 캡처 파일 크기: 8192 bytes
- [ ] 데이터 무결성: 100%
- [ ] MIPI PHY 에러: 0건

---

## 🐛 자주 발생하는 이슈

| 문제 | 원인 | 해결 |
|------|------|------|
| /dev/video0 없음 | 드라이버 미로드 | `modprobe imx8-isi-cap` |
| dmesg 에러 | DT 설정 오류 | mipi_csi/isi 노드 재확인 |
| 파일 크기 0 | MIPI 데이터 미수신 | FPGA 출력 확인 (ILA) |
| 데이터 불일치 | Endian 오류 | verify.py 변환 로직 점검 |
| 정렬 에러 | stride 미정렬 | `512 % 64 = 0` 확인 |

---

## 💡 핵심 명령어

### 시스템 확인
```bash
# 비디오 노드
ls -l /dev/video*

# 드라이버
lsmod | grep imx8_isi

# ISI clock
cat /sys/kernel/debug/clk/clk_summary | grep isi

# 파이프라인
media-ctl -p
```

### 캡처
```bash
# RAW8 캡처
v4l2-ctl --device /dev/video0 \
  --set-fmt-video=width=512,height=16,pixelformat=BA81 \
  --stream-mmap --stream-to=capture.raw --stream-count=1

# 크기 확인
ls -l capture.raw  # 8192 bytes
```

### 검증
```bash
# Python 검증
python3 scripts/verify.py capture.raw

# dmesg 로그
dmesg | tail -50
dmesg | grep -i mipi
dmesg | grep -i isi
```

---

## 🎯 개발 가이드

**상세 Task 가이드**: [../../agent-guide/agent-prompts.md](../../agent-guide/agent-prompts.md)  
**5일 계획**: [../../agent-guide/todo-list-5days.md](../../agent-guide/todo-list-5days.md)
