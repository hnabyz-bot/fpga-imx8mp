# FPGA-i.MX8MP MIPI CSI-2 통신 프로젝트 문서

## 📚 문서 구조

이 프로젝트는 **FPGA(Xilinx Artix-7)에서 i.MX8MP로 MIPI CSI-2를 통한 데이터 전송**을 구현합니다.

### 🎯 필수 읽기 순서

1. **[mipi-project-plan.md](mipi-project-plan.md)** - 프로젝트 전체 개요
   - 시스템 사양 및 제약사항
   - 구현 단계 및 패킷 구조
   - 예상 이슈 및 검증 기준

2. **[agent-prompts.md](agent-prompts.md)** - AI 에이전트 작업 지침
   - 작업 흐름 및 핵심 원칙
   - Phase별 상세 가이드
   - 출력 형식 및 체크포인트

3. **[todo-list-5days.md](todo-list-5days.md)** - 5일 작업 계획
   - Day별 구체적 작업 내용
   - 산출물 및 검증 조건
   - 전체 완료 조건

4. **[system-flow-diagram.md](system-flow-diagram.md)** - 시스템 플로우 차트
   - 10개의 Mermaid 다이어그램
   - 데이터 흐름 및 상태 전환
   - 에러 처리 플로우

---

## 🔑 핵심 개념

### 시스템 초기화 순서
```
Power On → i.MX8MP Boot → FPGA Config (SPI) 
    → DONE 확인 → MIPI CSI-2 통신 시작
```

**중요**: FPGA Configuration은 i.MX8MP에서 SPI를 통해 이미 구현되어 있으며,  
작업 시작 전 **FPGA DONE 상태 확인 필수**

### 데이터 흐름
```
FPGA (256×16-bit) → 패킹 (512×RAW8) → MIPI TX → D-PHY (4-Lane)
    → MIPI RX → ISI → DRAM (64-byte 정렬)
```

### 핵심 제약사항
- **메모리 정렬**: Stride = 512 bytes (64의 배수 필수)
- **Endian**: Little Endian (0xABCD → [0xCD, 0xAB])
- **최소 라인 수**: 16줄 (원본 1줄을 16번 반복)
- **ISP 우회**: ISI Direct Path 사용

---

## 📋 작업 체크리스트

### Phase 1: FPGA 구현
- [ ] FPGA Configuration 완료 확인
- [ ] Vivado MIPI CSI-2 TX IP 설정
- [ ] 16-bit → RAW8 데이터 패킹 모듈
- [ ] MIPI FSM (FS/LS/Payload/FE)
- [ ] 가상 프레임 생성 (16줄 반복)

### Phase 2: i.MX8MP 설정
- [ ] Device Tree 수정 (mipi_csi, isi)
- [ ] ISP 우회 설정
- [ ] 드라이버 및 /dev/video0 확인
- [ ] ISI clock/power 활성화

### Phase 3: 통합 테스트
- [ ] v4l2-ctl 데이터 캡처
- [ ] 데이터 무결성 검증 (100%)
- [ ] 성능 측정 (FPS, 에러율)

---

## 🛠️ 필수 도구

### FPGA 개발
- Vivado Design Suite
- ILA (Integrated Logic Analyzer)
- Verilog 시뮬레이터

### i.MX8MP 개발
- Linux 커널 소스
- Device Tree Compiler (dtc)
- v4l2-ctl, media-ctl

### 검증
- Python 3.x
- NumPy (데이터 분석)

---

## 📊 주요 사양

| 항목 | 값 |
|------|-----|
| FPGA | Xilinx Artix-7 XC7A35T |
| AP | NXP i.MX8MP |
| 인터페이스 | MIPI CSI-2 (4 Data Lanes) |
| 데이터 타입 | RAW8 (0x2A) |
| 해상도 | 512 × 16 (전송) |
| Stride | 512 bytes (64-byte 정렬) |

---

## 🚨 주의사항

### 반드시 확인할 사항
1. **FPGA DONE 상태**: 모든 MIPI 작업 전 확인 필수
2. **64-byte 정렬**: `512 % 64 = 0` 검증
3. **AXI Handshake**: `TVALID && TREADY` 동시 High
4. **ISP 우회**: Device Tree에서 명확히 설정

### 금지 사항
- ❌ FPGA Config 완료 전 MIPI 작업 시작
- ❌ TREADY 무시하고 데이터 전송
- ❌ 제약사항 분석 없이 코드 작성
- ❌ 자가 검토 생략

---

## 📖 상세 문서 가이드

### [mipi-project-plan.md](mipi-project-plan.md)
**읽어야 할 사람**: 전체 프로젝트 참여자
**핵심 내용**:
- 시스템 아키텍처 및 데이터 사양
- Phase별 구현 단계 및 산출물
- MIPI 패킷 구조 및 메모리 맵
- 예상 이슈 및 검증 기준

**주요 섹션**:
1. 시스템 사양 (하드웨어, 데이터, 경로)
2. 핵심 제약사항 (초기화, FPGA, i.MX8MP)
3. 구현 단계 (Phase 1/2/3)
4. 패킷 구조 (FS/LS/Payload/FE)
5. 메모리 맵 (Endian 변환)
6. 예상 이슈 및 대응
7. 검증 기준 (정량/정성)

### [agent-prompts.md](agent-prompts.md)
**읽어야 할 사람**: AI 에이전트 및 개발자
**핵심 내용**:
- 작업 흐름 및 핵심 원칙
- Phase별 상세 Task 가이드
- 필수 출력 형식 (템플릿)
- 기술 스펙 Quick Reference
- 체크포인트 및 디버깅 가이드

**주요 섹션**:
1. 작업 흐름 (분석 → 구현 → 검토 → 검증)
2. 핵심 원칙 (제약사항, 자가 검토, 역할 분담)
3. Phase 1: FPGA 로직 (IP 설정, 패킹, FSM)
4. Phase 2: i.MX8MP 설정 (DTS, 드라이버)
5. Phase 3: 통합 테스트 (캡처, 검증)
6. 출력 형식 (코드 작성/문제 발생)
7. 기술 스펙 (MIPI 패킷, 메모리 정렬, D-PHY)
8. 체크포인트 (FPGA/i.MX8MP/통합)
9. 디버깅 가이드 (증상별 대응)

### [todo-list-5days.md](todo-list-5days.md)
**읽어야 할 사람**: 프로젝트 매니저 및 개발자
**핵심 내용**:
- 5일간 Day별 작업 계획
- 각 Task의 작업 내용/산출물/검증
- 전체 완료 조건 및 산출물
- 문제 발생 시 대응 방안

**주요 섹션**:
- Day 1: 사양 확정 (FPGA Config 확인, 데이터 변환, 메모리 맵)
- Day 2: 기본 모듈 (16to8 변환, Device Tree)
- Day 3: MIPI 프로토콜 (FSM, 가상 프레임, ISI 드라이버)
- Day 4: 통합 및 배포 (Vivado 빌드, 커널 컴파일)
- Day 5: 검증 (데이터 캡처, 무결성 검증, 성능 측정)
- 전체 완료 조건 (산출물, 검증 지표, 문제 대응)

### [system-flow-diagram.md](system-flow-diagram.md)
**읽어야 할 사람**: 모든 참여자 (시각적 이해 필요 시)
**핵심 내용**:
- 10개의 Mermaid 다이어그램
- 시스템 아키텍처부터 에러 처리까지 시각화
- 5일 작업 간트 차트

**포함된 차트**:
1. 전체 시스템 아키텍처
2. 데이터 변환 플로우
3. MIPI 프레임 전송 시퀀스
4. FPGA FSM 상태 다이어그램
5. i.MX8MP 데이터 처리 플로우
6. AXI4-Stream Handshake 타이밍
7. 메모리 맵 및 데이터 복원
8. 에러 처리 플로우
9. 5일 작업 간트 차트
10. 시스템 상태 다이어그램

**차트 활용**:
- VS Code: `Ctrl+Shift+V` (Markdown Preview Mermaid Support 확장 필요)
- 온라인: https://mermaid.live/
- GitHub: 자동 렌더링

---

## 🎯 빠른 시작 가이드

### 1단계: 문서 읽기
```
mipi-project-plan.md → agent-prompts.md → todo-list-5days.md
```

### 2단계: FPGA Configuration 확인
```bash
# DONE 핀 확인 (GPIO)
cat /sys/class/gpio/gpioXXX/value  # 1이면 완료

# 또는 상태 레지스터 확인
# (구현에 따라 다름)
```

### 3단계: 작업 시작
- **Day 1**: [todo-list-5days.md](todo-list-5days.md#day-1) 참조
- **Task별 가이드**: [agent-prompts.md](agent-prompts.md#2-단계별-상세-가이드) 참조
- **플로우 확인**: [system-flow-diagram.md](system-flow-diagram.md) 참조

---

## 🔍 자주 참조하는 정보

### MIPI CSI-2 패킷
```
FS (0x00) → [LS (0x02) → Payload (512B RAW8)] × 16 → FE (0x01)
```

### 메모리 정렬 검증
```python
stride = 512  # bytes
assert stride % 64 == 0, "64-byte alignment required"
```

### AXI4-Stream 전송 조건
```verilog
if (TVALID && TREADY) begin
    // 데이터 전송
end
```

### Device Tree 핵심 설정
```dts
&mipi_csi {
    data-lanes = <1 2 3 4>;
};

&isi_0 {
    width = <512>;
    height = <16>;
    stride = <512>;  // 64-byte aligned
};
```

---

## 📞 문제 발생 시

### 디버깅 순서
1. **로그 확인**: `dmesg | tail -50`
2. **타이밍 분석**: ILA, ChipScope
3. **하드웨어 점검**: 전원, Clock, 핀 연결
4. **문서 참조**: [agent-prompts.md 섹션 6](agent-prompts.md#6-디버깅-가이드)

### 주요 이슈 Quick Fix
| 증상 | 해결 방안 |
|------|-----------|
| `/dev/video0` 없음 | `modprobe imx8-isi-cap` |
| 데이터 전부 0x00 | ILA로 FPGA 출력 확인 |
| 프레임 인식 실패 | Height ≥ 16 확인 |
| 메모리 정렬 에러 | stride = 512 확인 |

---

## 📝 작업 진행 상황 추적

### 체크리스트 사용법
각 문서의 체크박스 `[ ]`를 완료 시 `[x]`로 변경하여 진행 상황 추적

### 산출물 관리
```
project/
├── fpga/
│   ├── data_pack_16to8.v
│   ├── mipi_csi2_tx_fsm.v
│   └── *.bit
├── imx8mp/
│   ├── *.dts
│   ├── *.dtb
│   └── capture.sh
└── validation/
    ├── verify.py
    └── report.md
```

---

## 🚀 성공 기준

프로젝트는 다음 조건을 **모두** 충족해야 성공:

### 필수 산출물 ✅
- [ ] FPGA 비트스트림 (.bit)
- [ ] Device Tree (.dts, .dtb)
- [ ] 캡처 스크립트 (capture.sh)
- [ ] 검증 스크립트 (verify.py)
- [ ] 최종 보고서

### 검증 지표 ✅
- [ ] 데이터 무결성: 100%
- [ ] MIPI PHY 에러: 0건
- [ ] 메모리 정렬: 64-byte
- [ ] 프레임 구조: FS → 16 Lines → FE
- [ ] ISP 우회: 확인

---

**최종 수정**: 2026-01-07  
**문서 버전**: 1.0  
**프로젝트**: FPGA-i.MX8MP MIPI CSI-2 Communication
