# Quick Reference - 핵심 요약

## 🚀 빠른 체크리스트

### 작업 시작 전
- [ ] FPGA Configuration 완료 확인 (DONE = High)
- [ ] 문서 읽기: README.md → mipi-project-plan.md → agent-prompts.md
- [ ] 작업 계획 확인: todo-list-5days.md

### 코드 작성 전
- [ ] 제약사항 명시 (64-byte 정렬, Endian, 최소 라인 수)
- [ ] 설계 목표 명확화
- [ ] 상대 플랫폼 고려 (FPGA ↔ i.MX8MP)

### 코드 작성 후
- [ ] 잠재적 오류 3가지 식별 및 해결
- [ ] 상호 검증 (FPGA 설계자 ↔ i.MX8MP 설계자)
- [ ] 체크포인트 확인
- [ ] 출력 형식 준수

---

## 💡 핵심 수치

| 항목 | 값 | 검증 |
|------|-----|------|
| 입력 데이터 | 256 × 16-bit | FPGA 내부 |
| 전송 포맷 | 512 × RAW8 | MIPI 전송 |
| Stride | 512 bytes | `512 % 64 = 0` ✅ |
| 최소 라인 수 | 16 lines | i.MX8MP ISI 요구 |
| 파일 크기 | 8192 bytes | `512 × 16` |

---

## 🔧 자주 사용하는 명령어

### FPGA Configuration 확인
```bash
# DONE 핀 확인
cat /sys/class/gpio/gpioXXX/value
```

### i.MX8MP 상태 확인
```bash
# 비디오 노드 확인
ls -l /dev/video*

# 드라이버 확인
lsmod | grep imx8_isi

# ISI clock 확인
cat /sys/kernel/debug/clk/clk_summary | grep isi

# 디바이스 리스트
v4l2-ctl --list-devices

# 파이프라인 확인
media-ctl -p
```

### 데이터 캡처
```bash
# RAW8 캡처
v4l2-ctl --device /dev/video0 \
  --set-fmt-video=width=512,height=16,pixelformat=BA81 \
  --stream-mmap --stream-to=capture.raw --stream-count=1

# 파일 크기 확인
ls -l capture.raw  # 8192 bytes 여야 함
```

### 로그 확인
```bash
# 커널 로그 (최근 50줄)
dmesg | tail -50

# MIPI 관련 로그
dmesg | grep -i mipi

# ISI 관련 로그
dmesg | grep -i isi
```

---

## 🐛 빠른 문제 해결

| 증상 | 즉시 확인 | 해결 |
|------|-----------|------|
| `/dev/video0` 없음 | `lsmod \| grep isi` | `modprobe imx8-isi-cap` |
| 데이터 전부 0 | ILA 신호 확인 | FPGA 출력 점검 |
| 캡처 실패 | `dmesg` 확인 | 드라이버 재로드 |
| 파일 크기 오류 | Height 확인 | 16줄 이상 |
| 정렬 에러 | `512 % 64` 계산 | Stride 수정 |

---

## 📐 데이터 변환 공식

### Little Endian 변환
```
송신 (FPGA):
  Data[i] = 0xABCD
  → Byte[2i]   = 0xCD (Lower)
  → Byte[2i+1] = 0xAB (Upper)

수신 (i.MX8MP):
  Memory[2i]   = 0xCD
  Memory[2i+1] = 0xAB

복원 (Python):
  Data[i] = (Memory[2i+1] << 8) | Memory[2i]
          = (0xAB << 8) | 0xCD
          = 0xABCD ✅
```

### 메모리 정렬 검증
```python
width = 512
bytes_per_pixel = 1  # RAW8
stride = width * bytes_per_pixel
assert stride % 64 == 0  # 필수!
```

---

## 🎯 MIPI 패킷 순서

```
Frame Start:
  FS Packet (0x00)

For each line (0 to 15):
  LS Packet (0x02) + Line Number
  [Blanking: 최소 10 cycles]
  Payload: 512 bytes RAW8 (0x2A)
  [Line 간 간격]

Frame End:
  FE Packet (0x01)
```

---

## ⚡ AXI4-Stream 핵심

```verilog
// 전송 조건 (필수)
if (TVALID && TREADY) begin
    // 데이터 전송
end

// 신호 타이밍
TLAST = 1      // 라인 마지막 바이트 (512번째)
TUSER[0] = 1   // Frame Start
```

**금지**: `TREADY` 무시하고 데이터 전송 ❌

---

## 📊 검증 체크리스트

### FPGA
- [ ] TVALID && TREADY Handshake
- [ ] TLAST 타이밍 정확
- [ ] TUSER[0] Frame Start
- [ ] Backpressure 처리
- [ ] CDC (Clock Domain Crossing)

### i.MX8MP
- [ ] Stride = 512, 64-byte 정렬
- [ ] ISP 완전 우회
- [ ] ISI clock 활성화
- [ ] /dev/video0 생성
- [ ] DMA 버퍼 정상

### 통합
- [ ] 파일 크기 8192 bytes
- [ ] 데이터 무결성 100%
- [ ] MIPI PHY 에러 0건
- [ ] 연속 캡처 가능

---

## 📚 문서 링크

- **전체 개요**: [README.md](README.md)
- **프로젝트 계획**: [mipi-project-plan.md](mipi-project-plan.md)
- **작업 지침**: [agent-prompts.md](agent-prompts.md)
- **5일 계획**: [todo-list-5days.md](todo-list-5days.md)
- **플로우 차트**: [system-flow-diagram.md](system-flow-diagram.md)

---

## 🎓 자주 하는 실수

1. **FPGA Config 미확인**: MIPI 작업 전 DONE 상태 확인 필수
2. **TREADY 무시**: AXI Handshake 반드시 확인
3. **정렬 무시**: Stride가 64의 배수가 아니면 에러
4. **라인 수 부족**: 최소 16줄 필요
5. **ISP 우회 실패**: Device Tree에서 명확히 설정

---

## 🚨 비상 연락망

**문제 발생 시 순서**:
1. dmesg 로그 확인
2. 디버깅 가이드 참조 ([agent-prompts.md 섹션 6](agent-prompts.md#6-디버깅-가이드))
3. 타이밍 분석 (ILA)
4. 하드웨어 점검
5. 문서 재확인

---

**최종 수정**: 2026-01-07  
**참고**: 이 문서는 빠른 참조용입니다. 상세 내용은 각 문서 참조
