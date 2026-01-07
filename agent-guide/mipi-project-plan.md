# FPGA-i.MX8MP MIPI CSI-2 통신 프로젝트

## 1. 목표
FPGA(Xilinx Artix-7 XC7A35T)에서 i.MX8MP로 16-bit 데이터를 MIPI CSI-2 4-Lane을 통해 전송하고, ISP를 우회하여 ISI로 직접 메모리에 저장.

---

## 2. 시스템 사양

### 하드웨어
- **FPGA**: Xilinx Artix-7 XC7A35T
- **AP**: NXP i.MX8MP
- **인터페이스**: MIPI CSI-2 (4 Data Lanes + 1 Clock Lane)
- **물리 계층**: MIPI D-PHY

### 데이터 사양
| 항목 | 값 | 설명 |
|------|-----|------|
| 입력 데이터 | 256 × 1 (16-bit) | FPGA 내부 데이터 |
| 전송 포맷 | 512 × 1 (RAW8) | MIPI 전송용 변환 |
| 데이터 타입 | RAW8 (0x2A) | MIPI CSI-2 Data Type |
| Endian | Little Endian | 0xABCD → [0xCD, 0xAB] |
| Stride | 512 bytes | 64-byte 정렬 충족 ✅ |
| 최소 라인 수 | 16 lines | i.MX8MP ISI 요구사항 |

### 데이터 경로
```
FPGA (16-bit) → 패킹 (RAW8) → MIPI TX → D-PHY (4-Lane) 
    → MIPI RX → ISI → DRAM
```

**ISP 우회**: ISI Direct Path 사용

---

## 3. 핵심 제약사항

### 시스템 초기화
1. **FPGA Configuration**: i.MX8MP에서 SPI를 통해 FPGA 설정 (이미 구현됨)
2. **Configuration 완료 확인**: FPGA DONE 상태 확인 후 MIPI 작업 시작
3. **초기화 순서**: i.MX8MP Boot → FPGA Config → DONE 확인 → MIPI 통신

### FPGA
1. **데이터 변환**: 16-bit → 8-bit (Little Endian)
2. **MIPI 프로토콜**: FS, LS, Payload, FE 패킷 구성
3. **AXI4-Stream**: TVALID && TREADY Handshake 필수
4. **최소 라인 수**: 원본 1줄 → 16줄 반복 전송

### i.MX8MP
1. **메모리 정렬**: Stride = 512 bytes (64의 배수 필수)
   - 검증: `512 % 64 = 0` ✅
2. **ISP 우회**: Device Tree에서 ISI Direct Path 설정
3. **Clock/Power**: ISI clock 및 power domain 활성화 필요

---

## 4. 구현 단계

### Phase 1: FPGA 구현
**목표**: MIPI CSI-2 TX 로직 구현

| Task | 내용 | 산출물 |
|------|------|--------|
| 1-1 | Vivado MIPI CSI-2 TX IP 설정 (4-Lane, RAW8) | TCL 스크립트 |
| 1-2 | 16-bit → RAW8 패킹 모듈 (Little Endian) | Verilog 코드 |
| 1-3 | MIPI FSM (FS/LS/Payload/FE) | Verilog 코드 |
| 1-4 | 1줄 → 16줄 반복 로직 (ISI 최소 라인 충족) | Verilog 코드 |
| 1-5 | 통합 테스트 (ILA로 신호 검증) | 시뮬레이션 결과 |

**핵심 검증**:
- [ ] AXI4-Stream Handshake (`TVALID && TREADY`)
- [ ] TLAST 타이밍 (라인 마지막 바이트)
- [ ] TUSER[0] (Frame Start 표시)

### Phase 2: i.MX8MP 설정
**목표**: MIPI CSI-2 RX 및 ISI 파이프라인 활성화

| Task | 내용 | 산출물 |
|------|------|--------|
| 2-1 | Device Tree 수정 (mipi_csi, isi 노드) | DTS 파일 |
| 2-2 | 드라이버 설정 (가상 센서 매핑) | 설정 스크립트 |
| 2-3 | 비디오 노드 확인 (/dev/video0) | 검증 스크립트 |
| 2-4 | ISI clock/power 확인 | 검증 명령어 |

**핵심 검증**:
- [ ] Stride 정렬: `512 % 64 = 0` ✅
- [ ] ISP 우회 확인
- [ ] `/dev/video0` 노드 생성

### Phase 3: 통합 테스트
**목표**: 데이터 무결성 검증

| Task | 내용 | 산출물 |
|------|------|--------|
| 3-1 | v4l2-ctl 기반 데이터 캡처 | Bash 스크립트 |
| 3-2 | RAW8 → 16-bit 복원 및 검증 | Python 스크립트 |
| 3-3 | 성능 측정 (FPS, 에러율) | 테스트 보고서 |

**핵심 검증**:
- [ ] 파일 크기: 512 × 16 = 8192 bytes
- [ ] 데이터 무결성: 송신 == 수신
- [ ] 에러 없음 (dmesg, MIPI PHY)

---

## 5. 패킷 구조

### MIPI CSI-2 프레임 구성
```
┌─────────────────────────────────────┐
│ FS (Frame Start)                    │ Short Packet (0x00)
├─────────────────────────────────────┤
│ LS (Line Start) - Line 0            │ Short Packet (0x02)
│ Payload - 512 bytes RAW8            │ Long Packet (0x2A)
├─────────────────────────────────────┤
│ LS (Line Start) - Line 1            │
│ Payload - 512 bytes RAW8            │
├─────────────────────────────────────┤
│ ... (총 16 라인 반복)                │
├─────────────────────────────────────┤
│ FE (Frame End)                      │ Short Packet (0x01)
└─────────────────────────────────────┘
```

### 패킷 상세
**Short Packet (4 bytes)**:
- Data ID: 1 byte (FS=0x00, FE=0x01, LS=0x02)
- Data Field: 2 bytes (Frame/Line Number)
- ECC: 1 byte

**Long Packet (518 bytes)**:
- Header: Data ID (0x2A) + Word Count (512) + ECC
- Payload: 512 bytes
- Footer: CRC-16 (2 bytes)

---

## 6. 메모리 맵 (i.MX8MP)

### RAW8 → 16-bit 복원
```
메모리 레이아웃 (Little Endian):
Offset  | Byte 0 | Byte 1 | Byte 2 | Byte 3 | ...
--------|--------|--------|--------|--------|----
0x0000  | 0xCD   | 0xAB   | 0x34   | 0x12   | ...
        └─ Data[0] ─┘     └─ Data[1] ─┘

복원:
Data[0] = (Byte1 << 8) | Byte0 = 0xABCD
Data[1] = (Byte3 << 8) | Byte2 = 0x1234
```

### Stride 계산
```
stride = width × bytes_per_pixel
       = 512 × 1 = 512 bytes
512 % 64 = 0 ✅ (정렬 조건 충족)
```

---

## 7. 예상 이슈 및 대응

| 이슈 | 원인 | 대응 방안 |
|------|------|-----------|
| 프레임 인식 실패 | 라인 수 부족 (< 16) | 동일 라인 반복 전송 |
| 데이터 손실 | Backpressure 미처리 | FIFO 추가 또는 Flow Control |
| 메모리 정렬 에러 | Stride 미정렬 | 512 bytes (64 배수) 사용 |
| MIPI PHY 에러 | 타이밍 위반 | D-PHY 파라미터 재조정 |
| `/dev/video0` 미생성 | 드라이버 미로드 | `modprobe imx8-isi-cap` |

---

## 8. 검증 기준

### 정량적 지표
- **데이터 무결성**: 100% (불일치 0 bytes)
- **프레임 레이트**: 목표 FPS 달성
- **에러율**: MIPI PHY 에러 0건
- **메모리 효율**: 64-byte 정렬 100% 준수

### 정성적 지표
- dmesg에서 프레임 시작/종료 로그 정상 출력
- v4l2-ctl로 연속 캡처 가능
- 시스템 안정성 (장시간 동작)


