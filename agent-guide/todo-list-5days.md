# 5일 집중 작업 계획

## 작업 원칙
- **하루 단위 목표**: 각 날짜별 핵심 목표 달성 후 다음 단계 진행
- **검증 필수**: 매일 작업 종료 전 해당 단계 검증 완료
- **상호 검토**: FPGA ↔ i.MX8MP 설계자 관점 교차 검증

---

## Day 1: 사양 확정 및 기초 분석
**목표**: 데이터 변환 규칙 및 메모리 정렬 설계 완료

### Task 1-0: FPGA Configuration 완료 확인 (전제조건)
**작업 내용**:
- i.MX8MP에서 SPI를 통한 FPGA configuration 확인 (이미 구현됨)
- FPGA DONE 상태 확인 방법 정리
  - DONE 핀 GPIO 읽기
  - 또는 FPGA 상태 레지스터 확인
- Configuration 실패 시 재시도 로직 확인

**산출물**:
- FPGA DONE 확인 스크립트
- Configuration 상태 확인 문서

**검증**:
- [ ] FPGA configuration 완료 확인
- [ ] DONE 신호 High 확인
- [ ] FPGA User Mode 진입 확인

### Task 1-1: 데이터 변환 규칙 정의 (FPGA)
**작업 내용**:
- 16-bit → 8-bit 변환 시 Byte Order 정의
  - Little Endian: 0xABCD → [0xCD, 0xAB]
- 256개 16-bit 데이터 → 512 bytes RAW8 변환 타이밍 계산
- AXI4-Stream 전송 대역폭 계산

**산출물**:
- 데이터 변환 명세서 (바이트 맵 포함)
- 타이밍 계산서

**검증**:
- [ ] Endian 변환 명확히 정의
- [ ] 전송 대역폭 i.MX8MP 수신 대역폭 이내

### Task 1-2: ISI 메모리 맵 분석 (i.MX8MP)
**작업 내용**:
- ISI 레지스터 설정 분석
  - RAW8 수신 시 메모리 저장 구조
  - Stride 계산: 512 bytes
  - 64-byte 정렬 검증: `512 % 64 = 0` ✅
- 예상 메모리 레이아웃 다이어그램 작성

**산출물**:
- ISI 메모리 맵 문서
- Stride 계산 검증서

**검증**:
- [ ] 64-byte 정렬 충족
- [ ] RAW8 포맷 정상 매핑

### Task 1-3: 상호 검증
**작업 내용**:
- 🔵 FPGA 출력 주파수 vs 🟢 i.MX8MP 수신 대역폭
- 데이터 포맷 정합성 (512 bytes, RAW8)
- 타이밍 여유(Margin) 계산

**완료 조건**:
- ✅ 대역폭 정합성 확인
- ✅ 타이밍 여유 20% 이상

---

## Day 2: 기본 모듈 개발
**목표**: 데이터 변환 및 Device Tree 기본 구조 완성

### Task 2-1: 16-bit → 8-bit 변환 모듈 (FPGA)
**작업 내용**:
- Verilog 모듈 작성: `data_pack_16to8.v`
  - 입력: 256개 16-bit 데이터
  - 출력: 512 bytes (AXI4-Stream)
  - Little Endian 변환 적용
- FIFO Overflow 방지 로직
- Backpressure 처리 (TREADY 신호 반영)

**산출물**:
- `data_pack_16to8.v` 파일
- 테스트벤치 (시뮬레이션 결과)

**검증**:
- [ ] `TVALID && TREADY` Handshake 동작
- [ ] FIFO Overflow 방지 확인
- [ ] Endian 변환 정확성 (시뮬레이션)

### Task 2-2: Device Tree 기본 노드 작성 (i.MX8MP)
**작업 내용**:
- DTS 파일 수정
  - `mipi_csi` 노드: data-lanes = <1 2 3 4>
  - `isi` 노드: width=512, height=16, stride=512
  - 엔드포인트 연결 (mipi_csi → isi)
- ISP 우회 설정 (`bypass-isp`)

**산출물**:
- 수정된 DTS 파일
- 컴파일 스크립트

**검증**:
- [ ] DTS 컴파일 성공
- [ ] Stride = 512 (64-byte 정렬)

### Task 2-3: 자가 검토
**작업 내용**:
- FPGA 모듈 잠재적 오류 3가지 식별
- Device Tree 설정 오류 가능성 검토
- 해결책 적용

**완료 조건**:
- ✅ 오류 3가지 식별 및 해결

---

## Day 3: MIPI 프로토콜 구현
**목표**: MIPI CSI-2 FSM 및 최소 라인 수 충족

### Task 3-1: MIPI CSI-2 TX FSM 구현 (FPGA)
**작업 내용**:
- FSM 설계: IDLE → FS → LS → PAYLOAD → FE
  - FS 패킷: Short Packet (0x00)
  - LS 패킷: Short Packet (0x02) + Line Number
  - Payload: 512 bytes RAW8
  - FE 패킷: Short Packet (0x01)
- Blanking Time 추가 (최소 10 cycles)
- TLAST, TUSER 신호 제어

**산출물**:
- `mipi_csi2_tx_fsm.v` 파일
- 타이밍 다이어그램

**검증**:
- [ ] FS/FE 패킷 정상 생성
- [ ] TLAST = 1 (라인 마지막)
- [ ] TUSER[0] = 1 (Frame Start)

### Task 3-2: 가상 프레임 생성 (FPGA)
**작업 내용**:
- 1줄 데이터 → 16줄 반복 전송 로직
- i.MX8MP ISI 최소 라인 수(16줄) 충족
- Line Number 증가 로직

**산출물**:
- 가상 프레임 생성 모듈
- 시뮬레이션 결과 (16줄 확인)

**검증**:
- [ ] 총 16줄 전송 확인
- [ ] Line Number 정상 증가 (0~15)

### Task 3-3: ISI 드라이버 설정 (i.MX8MP)
**작업 내용**:
- ISI 해상도 설정: 512 × 16
- Stride 설정: 512 bytes
- Format 설정: RAW8 (pixelformat 'BA81' 또는 'GREY')
- Clock 및 Power domain 확인

**산출물**:
- 드라이버 설정 스크립트
- 확인 명령어 모음

**검증**:
- [ ] ISI clock 활성화 확인
- [ ] 파라미터 설정 정확성

---

## Day 4: 통합 및 배포
**목표**: FPGA 빌드 및 i.MX8MP 커널 배포

### Task 4-1: Vivado MIPI TX IP 설정 (FPGA)
**작업 내용**:
- MIPI CSI-2 TX Subsystem IP 설정
  - 4-Lane, RAW8 (Data Type 0x2A)
  - D-PHY 타이밍 파라미터 설정
  - Virtual Channel = 0
- XDC 제약 파일 작성 (핀 맵핑, 타이밍)
- 통합 빌드 및 비트스트림 생성

**산출물**:
- Vivado 프로젝트 파일
- 비트스트림 (.bit 파일)
- TCL 스크립트

**검증**:
- [ ] 타이밍 에러 없음
- [ ] 리소스 사용률 허용 범위

### Task 4-2: 커널 컴파일 및 배포 (i.MX8MP)
**작업 내용**:
- Device Tree 최종 확정
- 커널 컴파일 (Device Tree 포함)
- 보드 배포 준비
  - 커널 이미지
  - Device Tree Blob (.dtb)
  - 필요 시 드라이버 모듈

**산출물**:
- 커널 이미지
- DTB 파일
- 배포 스크립트

**검증**:
- [ ] 컴파일 에러 없음
- [ ] `/dev/video0` 노드 생성 확인

### Task 4-3: 64-byte 정렬 예외 처리 검토
**작업 내용**:
- Stride 미정렬 시 ISI 동작 분석
- 예외 처리 로직 확인
- dmesg 에러 로그 확인 방법 정리

**완료 조건**:
- ✅ 정렬 검증 완료 (512 % 64 = 0)
- ✅ 예외 처리 방안 문서화

---

## Day 5: 검증 및 디버깅
**목표**: 데이터 무결성 100% 검증

### Task 5-1: 데이터 캡처 (i.MX8MP)
**작업 내용**:
- v4l2-ctl 기반 캡처 스크립트 작성
  ```bash
  v4l2-ctl --device /dev/video0 \
           --set-fmt-video=width=512,height=16,pixelformat=BA81 \
           --stream-mmap --stream-to=capture.raw --stream-count=1
  ```
- 파일 크기 검증: 8192 bytes (512 × 16)
- 실패 시 dmesg 로그 수집

**산출물**:
- 캡처 스크립트 (`capture.sh`)
- 캡처 데이터 (`capture.raw`)

**검증**:
- [ ] 파일 크기: 8192 bytes
- [ ] 캡처 성공 (에러 없음)

### Task 5-2: 데이터 무결성 검증
**작업 내용**:
- Python 검증 스크립트 작성
  - RAW8 파일 읽기 (8192 bytes)
  - Little Endian 변환: 16-bit 복원
  - FPGA 원본 데이터와 바이트 단위 비교
  - 불일치 시: 오프셋, 기대값, 실제값 출력
- 검증 보고서 생성

**산출물**:
- 검증 스크립트 (`verify.py`)
- 검증 보고서

**검증**:
- [ ] 데이터 무결성: 100% (불일치 0 bytes)
- [ ] Endian 변환 정확성 확인

### Task 5-3: 성능 측정 및 최종 보고
**작업 내용**:
- 프레임 레이트 측정
- MIPI PHY 에러 카운터 확인
- 장시간 안정성 테스트 (100 프레임 이상)
- 최종 보고서 작성

**산출물**:
- 성능 측정 결과
- 최종 프로젝트 보고서

**검증**:
- [ ] MIPI PHY 에러: 0건
- [ ] 연속 캡처 성공
- [ ] 데이터 드롭 없음

---

## 전체 완료 조건

### 필수 산출물 (Deliverables)
- [ ] FPGA 비트스트림 (.bit)
- [ ] i.MX8MP Device Tree (.dts, .dtb)
- [ ] 데이터 캡처 스크립트 (capture.sh)
- [ ] 검증 스크립트 (verify.py)
- [ ] 최종 프로젝트 보고서

### 검증 지표
- [ ] 데이터 무결성: 100%
- [ ] MIPI PHY 에러: 0건
- [ ] 메모리 정렬: 64-byte (512 % 64 = 0 ✅)
- [ ] 프레임 구조: FS → 16 Lines → FE
- [ ] ISP 우회: 확인

### 문제 발생 시 대응
| 단계 | 문제 | 대응 |
|------|------|------|
| Day 1-2 | 대역폭 부족 | Clock 주파수 상향 조정 |
| Day 3 | 프레임 인식 실패 | 라인 수 증가 (16 → 32) |
| Day 4 | 타이밍 에러 | XDC 제약 재조정 |
| Day 5 | 데이터 불일치 | Endian 변환 재검토 |

---

**진행 상황 추적**: 각 Task 완료 시 체크박스 표시 및 산출물 확인