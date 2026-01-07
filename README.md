# FPGA-i.MX8MP MIPI CSI-2 Communication Project

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-available-brightgreen.svg)](agent-guide/README.md)

## 📖 프로젝트 개요

FPGA(Xilinx Artix-7 XC7A35T)에서 i.MX8MP로 16-bit 데이터를 MIPI CSI-2 4-Lane을 통해 전송하는 프로젝트입니다.

### 주요 특징
- ✅ FPGA Configuration via SPI (i.MX8MP → FPGA)
- ✅ MIPI CSI-2 4-Lane 데이터 전송
- ✅ ISP 우회, ISI Direct Path
- ✅ 64-byte 메모리 정렬 최적화
- ✅ 완전한 문서화 및 검증 스크립트

---

## 🚀 빠른 시작

### 1. 문서 읽기
모든 문서는 **[agent-guide](agent-guide/)** 폴더에 있습니다.

**추천 순서:**
```
1. agent-guide/README.md          - 전체 문서 가이드
2. agent-guide/QUICK-REFERENCE.md - 빠른 참조
3. agent-guide/mipi-project-plan.md - 프로젝트 계획
4. agent-guide/agent-prompts.md    - 작업 지침
5. agent-guide/todo-list-5days.md  - 5일 작업 계획
6. agent-guide/system-flow-diagram.md - 플로우 차트
```

### 2. 전제 조건 확인
```bash
# FPGA Configuration 완료 확인 (필수!)
cat /sys/class/gpio/gpioXXX/value  # 1이면 Config 완료
```

### 3. 작업 시작
**[5일 작업 계획](agent-guide/todo-list-5days.md)** 참조

---

## 📊 시스템 사양

| 항목 | 값 |
|------|-----|
| **FPGA** | Xilinx Artix-7 XC7A35T |
| **AP** | NXP i.MX8MP |
| **인터페이스** | MIPI CSI-2 (4 Data Lanes) |
| **데이터 타입** | RAW8 (0x2A) |
| **해상도** | 512 × 16 (전송) |
| **Stride** | 512 bytes (64-byte 정렬) |

---

## 🔧 시스템 아키텍처

```
Power On → i.MX8MP Boot → FPGA Config (SPI) → DONE 확인
    ↓
FPGA (256×16-bit) → 패킹 (512×RAW8) → MIPI TX → D-PHY (4-Lane)
    ↓
MIPI RX → ISI → DRAM (64-byte 정렬)
```

**핵심 특징:**
- FPGA Configuration: i.MX8MP가 SPI로 설정 (이미 구현됨)
- ISP 우회: ISI Direct Path 사용
- Endian: Little Endian (0xABCD → [0xCD, 0xAB])

---

## 📚 문서 구조

### 필수 문서
- **[README.md](agent-guide/README.md)** - 전체 프로젝트 가이드
- **[QUICK-REFERENCE.md](agent-guide/QUICK-REFERENCE.md)** - 핵심 요약 및 명령어
- **[mipi-project-plan.md](agent-guide/mipi-project-plan.md)** - 프로젝트 계획서
- **[agent-prompts.md](agent-guide/agent-prompts.md)** - AI 에이전트 작업 지침
- **[todo-list-5days.md](agent-guide/todo-list-5days.md)** - 5일 작업 계획
- **[system-flow-diagram.md](agent-guide/system-flow-diagram.md)** - 10개 Mermaid 차트

---

## 🎯 작업 체크리스트

### Phase 1: FPGA 구현
- [ ] FPGA Configuration 완료 확인
- [ ] Vivado MIPI CSI-2 TX IP 설정
- [ ] 16-bit → RAW8 패킹 모듈
- [ ] MIPI FSM (FS/LS/Payload/FE)
- [ ] 가상 프레임 생성 (16줄)

### Phase 2: i.MX8MP 설정
- [ ] Device Tree 수정
- [ ] ISP 우회 설정
- [ ] /dev/video0 확인
- [ ] ISI clock/power 활성화

### Phase 3: 검증
- [ ] v4l2-ctl 데이터 캡처
- [ ] 데이터 무결성 100%
- [ ] 성능 측정

---

## 🛠️ 개발 환경

### FPGA
- Vivado Design Suite
- ILA (Integrated Logic Analyzer)
- Verilog HDL

### i.MX8MP
- Linux Kernel (with Device Tree)
- v4l2-ctl, media-ctl
- Python 3.x (검증 스크립트)

---

## 💡 핵심 개념

### 메모리 정렬
```python
stride = 512 bytes  # 64-byte 정렬 필수
assert stride % 64 == 0  # ✅
```

### MIPI 패킷 구조
```
FS (0x00) → [LS (0x02) → Payload (512B)] × 16 → FE (0x01)
```

### AXI4-Stream Handshake
```verilog
if (TVALID && TREADY) begin
    // 데이터 전송
end
```

---

## 🐛 문제 해결

### 자주 발생하는 이슈

| 증상 | 해결 방안 |
|------|-----------|
| `/dev/video0` 없음 | `modprobe imx8-isi-cap` |
| 데이터 전부 0x00 | FPGA 출력 확인 (ILA) |
| 프레임 인식 실패 | 최소 16줄 확인 |
| 메모리 정렬 에러 | stride = 512 확인 |

**상세 가이드:** [QUICK-REFERENCE.md](agent-guide/QUICK-REFERENCE.md)

---

## 📖 상세 문서

각 문서의 역할:

| 문서 | 용도 | 독자 |
|------|------|------|
| [README.md](agent-guide/README.md) | 전체 가이드 | 모든 참여자 |
| [QUICK-REFERENCE.md](agent-guide/QUICK-REFERENCE.md) | 빠른 참조 | 개발자 |
| [mipi-project-plan.md](agent-guide/mipi-project-plan.md) | 프로젝트 계획 | PM, 개발자 |
| [agent-prompts.md](agent-guide/agent-prompts.md) | 작업 지침 | AI 에이전트 |
| [todo-list-5days.md](agent-guide/todo-list-5days.md) | 5일 계획 | 개발팀 |
| [system-flow-diagram.md](agent-guide/system-flow-diagram.md) | 차트 | 모든 참여자 |

---

## 🎨 시각화 자료

**[system-flow-diagram.md](agent-guide/system-flow-diagram.md)**에 10개의 Mermaid 차트 포함:
1. 전체 시스템 아키텍처
2. 데이터 변환 플로우
3. MIPI 프레임 전송 시퀀스
4. FPGA FSM 상태 다이어그램
5. i.MX8MP 데이터 처리 플로우
6. AXI4-Stream Handshake
7. 메모리 맵 및 데이터 복원
8. 에러 처리 플로우
9. 5일 작업 간트 차트
10. 시스템 상태 다이어그램

---

## 🚨 중요 사항

### 필수 확인
1. ✅ **FPGA DONE 상태** - 모든 작업 전 확인
2. ✅ **64-byte 정렬** - `512 % 64 = 0`
3. ✅ **AXI Handshake** - `TVALID && TREADY`
4. ✅ **ISP 우회** - Device Tree 설정

### 금지 사항
- ❌ FPGA Config 완료 전 MIPI 작업
- ❌ TREADY 무시
- ❌ 자가 검토 생략

---

## 📞 지원

문제 발생 시:
1. [QUICK-REFERENCE.md](agent-guide/QUICK-REFERENCE.md) 참조
2. [agent-prompts.md 섹션 6](agent-guide/agent-prompts.md#6-디버깅-가이드) 디버깅 가이드
3. dmesg 로그 확인
4. ILA 타이밍 분석

---

## 📝 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.

---

## 🙏 기여

기여를 환영합니다! Pull Request를 보내주세요.

---

**최종 수정**: 2026-01-07  
**버전**: 1.0  
**문서 개수**: 7개 (2,576줄)
