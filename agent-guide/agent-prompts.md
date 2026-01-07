# AI 에이전트 구동 지침

> **프로젝트**: FPGA-i.MX8MP MIPI CSI-2 통신  
> **목적**: 체계적이고 검증 가능한 고품질 코드 작성  
> **핵심**: 단계별 검증, 양방향 설계 검토, 명확한 출력 형식

---

## 🔄 작업 흐름
```
Task 시작 → [분석] → [구현] → [자가 검토] → [상호 검증] → [완료] → 다음 Task
```

**철칙**: 
- Task 단위로 작업
- 검증 완료 전 다음 단계 진행 금지
- FPGA Configuration 완료 확인 후 MIPI 작업 시작

---

## ⚠️ 전제 조건: FPGA Configuration 확인

**모든 MIPI 관련 작업 전 필수 확인**:
```bash
# FPGA DONE 상태 확인
# (i.MX8MP에서 SPI로 이미 Configuration 완료된 상태)

# 방법 1: GPIO를 통한 DONE 핀 확인
cat /sys/class/gpio/gpioXXX/value  # 1이면 Config 완료

# 방법 2: FPGA 상태 레지스터 확인
# (구현에 따라 다름)
```

**확인 사항**:
- [ ] FPGA Configuration 완료 (DONE = High)
- [ ] FPGA User Mode 진입
- [ ] 재시도 로직 동작 확인 (실패 시)

**주의**: Configuration 미완료 상태에서 MIPI 작업 시 하드웨어 오동작 가능

---

## 1. 핵심 원칙

### 1.1 작성 전 제약사항 명시
코드 작성 전 **반드시** 다음을 설명:
- **i.MX8MP ISI**: 64-byte 정렬 필수 (`stride % 64 == 0`)
- **FPGA D-PHY**: LP-11 → HS-Request → HS-0 초기화 시퀀스
- **MIPI CSI-2**: 최소 라인 수(16줄), Blanking Time

### 1.2 자가 검토 (필수)
코드 작성 후:
1. **잠재적 오류 3가지** 식별
2. 각 오류에 대한 **구체적 해결책** 제시
3. **적용 여부** 명시 (적용함/안 함 + 이유)

### 1.3 역할 분담 (The Rule of Two)
- 🔵 **FPGA 설계자**: 송신 측 로직 작성
- 🟢 **i.MX8MP 설계자**: 수신 측 비판적 검토
- 상호 정합성 확인 후 "✅ 검증 완료" 선언

---

## 2. 단계별 상세 가이드

### Phase 1: FPGA 로직 작성

#### Task 1-1: Vivado MIPI CSI-2 TX IP 설정
**요구사항**:
```
"Vivado MIPI CSI-2 TX Subsystem IP를 다음 사양으로 설정하는 TCL 스크립트 작성:
- 4-Lane, RAW8(Data Type 0x2A)
- D-PHY 타이밍 파라미터 명시 (tCLK-PREPARE, tCLK-ZERO, tHS-PREPARE)
- 각 파라미터가 MIPI D-PHY 규격을 충족하는지 계산 과정 포함"
```

**필수 확인**:
- [ ] Clock Lane 초기화 시퀀스 (LP-11 → HS Request → HS-0)
- [ ] Data Lane 4개 활성화
- [ ] Virtual Channel = 0 (기본값)

#### Task 1-2: 16-bit → RAW8 데이터 패킹 로직
**요구사항**:
```
"16-bit 데이터를 RAW8로 패킹하는 Verilog 모듈 작성:
- Byte Order: Little Endian 명시
- 입력: 256개 16-bit 데이터 → 출력: 512 bytes
- 예시: 0xABCD → [0xCD, 0xAB]
- i.MX8MP 메모리에 저장될 형태를 바이트 맵으로 예측"
```

**필수 확인**:
- [ ] Endian 변환 명확히 정의
- [ ] 메모리 맵 다이어그램 (Byte 0~511)
- [ ] 64-byte 정렬 보장 계산식: `512 % 64 = 0` ✅

#### Task 1-3: MIPI CSI-2 FSM 설계
**요구사항**:
```
"MIPI 프로토콜 FSM 설계:
- 상태: IDLE → FS → LS → PAYLOAD → FE → IDLE
- FS 패킷: Short Packet (Data ID=0x00, Frame Number)
- LS 패킷: Short Packet (Data ID=0x02, Line Number)
- Payload: 512 bytes RAW8 데이터
- FE 패킷: Short Packet (Data ID=0x01)
- Blanking Time: LS와 Payload 사이 최소 10 clock cycles
- 최소 라인 수 16줄 충족 방안 (동일 라인 반복 등)
- AXI4-Stream 신호 제어: TVALID, TREADY, TLAST, TUSER 타이밍 다이어그램"
```

**필수 확인**:
- [ ] `TVALID && TREADY`일 때만 데이터 전송 (❌ TREADY 무시 금지)
- [ ] TLAST = 1 (각 라인 마지막 바이트)
- [ ] TUSER[0] = 1 (Frame Start 표시)
- [ ] Backpressure 처리 (FIFO 또는 Flow Control)

---

### Phase 2: i.MX8MP 시스템 설정

#### Task 2-1: Device Tree 작성
**요구사항**:
```
"i.MX8MP Device Tree 수정:
1. mipi_csi 노드:
   - data-lanes = <1 2 3 4>
   - clock-lanes = <0>
2. isi 노드:
   - Width = 512, Height = 16
   - Stride 계산: stride = width * bytes_per_pixel = 512 * 1 = 512
   - 메모리 정렬 검증: 512 % 64 = 0 ✅
   - ISP 우회 경로 명시 (bypass-isp 속성 또는 직접 isi 연결)
3. 엔드포인트 연결 (mipi_csi → isi)"
```

**필수 확인**:
- [ ] stride = 512 bytes (64의 배수)
- [ ] Format: RAW8 (pixelformat = 'BA81' 또는 'GREY')
- [ ] ISP 완전 우회

#### Task 2-2: 드라이버 및 비디오 노드 확인
**요구사항**:
```
"다음을 확인하는 bash 스크립트 작성:
1. /dev/video0 노드 생성 확인
2. v4l2-ctl --list-devices 출력
3. media-ctl -p로 파이프라인 구성 확인
4. ISI clock 활성화 상태: cat /sys/kernel/debug/clk/clk_summary | grep isi"
```

---

### Phase 3: 통합 테스트

#### Task 3-1: 데이터 캡처 스크립트
**요구사항**:
```
"v4l2-ctl 기반 캡처 bash 스크립트:
1. 512x16 RAW8 프레임 캡처
2. 출력 파일: capture.raw
3. 파일 크기 검증: 8192 bytes (512 * 16)
4. 실패 시 dmesg 마지막 50줄 출력"
```

#### Task 3-2: 데이터 무결성 검증
**요구사항**:
```
"Python 검증 스크립트:
1. capture.raw 읽기 (512x16 = 8192 bytes)
2. RAW8 → 16-bit 복원 (Little Endian)
   - Byte 0, 1 → 0x0100 형태로 복원
3. FPGA 송신 원본 데이터와 바이트 단위 비교
4. 불일치 발견 시: 오프셋, 기대값, 실제값 출력
5. 성공 시: '데이터 무결성 검증 완료' 출력"
```

---

## 3. 필수 출력 형식

### 코드 작성 시
```
### Task [번호]: [제목]

[분석]
제약사항:
- [핵심 제약 2-3개]

[구현]
파일: path/to/file.v

(코드 작성)

주요 로직:
1. [핵심 로직 설명]
2. [핵심 로직 설명]

[자가 검토]
잠재적 오류 3가지:
1. ❌ 오류: [구체적 문제]
   ✅ 해결책: [구체적 방법]
   적용: [적용함/안 함 + 이유]

2. ❌ 오류: ...
   ✅ 해결책: ...
   적용: ...

3. ❌ 오류: ...
   ✅ 해결책: ...
   적용: ...

[상호 검증]
🔵 FPGA 관점:
- [확인 사항 1-2개]

🟢 i.MX8MP 관점:
- [확인 사항 1-2개]

정합성:
- [ ] 데이터 포맷 일치 (RAW8, 512 bytes)
- [ ] 타이밍 충족 (Blanking, 최소 라인 16줄)
- [ ] 메모리 정렬 (stride % 64 == 0)

[결과]
✅ 검증 완료 / ⚠️ 수정 필요
```

### 문제 발생 시
```
### ⚠️ [문제 요약]

증상: [관찰 현상]

원인 분석:
1. 가설: [추정] → 검증: [방법] → 결과: [확인]
2. 가설: ...

해결 방안:
- 방안 1: [수정 내용]
- 방안 2: ...

선택: [방안 번호 + 선택 이유]

(수정 코드)

재검증: [결과]
```

---

## 4. 기술 스펙 (Quick Reference)

### MIPI CSI-2 패킷 구조
```
[Short Packet] 4 bytes
- Data ID (1B): FS=0x00, FE=0x01, LS=0x02, LE=0x03
- Data Field (2B): Frame Number / Line Number
- ECC (1B)

[Long Packet] 4 + N + 2 bytes
- Header (4B): Data ID (RAW8=0x2A) + Word Count (2B) + ECC (1B)
- Payload (N bytes): 실제 데이터 (512 bytes)
- Footer (2B): CRC-16
```

### 메모리 정렬 규칙
```
stride = width × bytes_per_pixel
stride must be aligned to 64 bytes

계산 예시:
width = 512 pixels
RAW8 = 1 byte/pixel
stride = 512 × 1 = 512 bytes
512 % 64 = 0 ✅
```

### D-PHY 타이밍 (참고)
```
Clock Lane:
- tCLK-PREPARE: 38~95 ns
- tCLK-ZERO: 262~300 ns

Data Lane:
- tHS-PREPARE: 40~85 ns + 4×UI
- tHS-ZERO: 145~255 ns + 10×UI

UI = 1 / Data Rate
예: 1 Gbps → UI = 1 ns
```

### AXI4-Stream 신호
```
TVALID: Master가 유효한 데이터 전송 중
TREADY: Slave가 데이터 수신 준비됨
TLAST: 현재 전송의 마지막 바이트
TUSER[0]: Frame Start (SOF)

전송 조건: TVALID && TREADY (동시에 High)
```

---

## 5. 체크포인트

### FPGA
- [ ] AXI Handshake: `TVALID && TREADY`일 때만 전송
- [ ] TLAST 제어: 라인 마지막(512번째 바이트)에서 High
- [ ] TUSER[0]: Frame Start에서 High
- [ ] Backpressure 처리: TREADY=Low 시 데이터 유지
- [ ] CDC: MIPI clock ↔ AXI clock 간 동기화

### i.MX8MP
- [ ] Stride 정렬: `512 % 64 = 0` ✅
- [ ] ISP 우회: DT에서 `bypass-isp` 또는 직접 ISI 경로
- [ ] Clock 확인: `cat /sys/kernel/debug/clk/clk_summary | grep isi`
- [ ] 드라이버 로드: `lsmod | grep imx8_isi`
- [ ] 비디오 노드: `/dev/video0` 생성 확인

### 통합
- [ ] FS/FE 구분: dmesg에서 프레임 경계 로그
- [ ] 데이터 무결성: 송신 == 수신 (바이트 비교)
- [ ] 프레임 연속성: 데이터 드롭 없음

---

## 6. 디버깅 가이드

| 증상 | 원인 | 확인 방법 | 해결 방안 |
|------|------|-----------|-----------|
| `/dev/video0` 미생성 | 드라이버 미로드 | `lsmod \| grep imx8_isi` | `modprobe imx8-isi-cap` |
| 데이터 전부 0x00 | MIPI 미도달 | ILA로 FPGA 출력 | D-PHY 초기화 재점검 |
| 데이터 일부 손실 | Backpressure 누락 | TREADY 모니터링 | FIFO 추가 |
| 프레임 인식 실패 | 라인 수 부족 | Height 확인 | 16줄 이상으로 조정 |
| 메모리 정렬 에러 | stride 미정렬 | `stride % 64` 계산 | 64 배수로 조정 |

**디버깅 순서**: 로그 확인 → 타이밍 분석 → 하드웨어 점검 → 사용자 문의

---

## 7. 금지 사항

- ❌ 제약사항 설명 없이 코드 작성
- ❌ 자가 검토 생략
- ❌ 모호한 표현 ("괜찮을 것 같습니다")
- ❌ 검증 없이 다음 Task 진행
- ❌ 출력 형식 무시

---

## 8. 작업 완료 조건

다음을 **모두** 충족해야 Task 완료:
1. ✅ 코드/설정 작성 완료
2. ✅ 잠재적 오류 3가지 식별 및 해결
3. ✅ 상호 검증 (FPGA ↔ i.MX8MP 정합성)
4. ✅ 체크포인트 확인
5. ✅ 출력 형식 준수