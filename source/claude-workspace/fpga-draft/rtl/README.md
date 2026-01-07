# FPGA Draft - RTL 작업 공간 (Claude)

Claude가 FPGA RTL 코드를 작성하는 폴더입니다.

## 📝 작업 예정 파일

- `data_pack_16to8.v` - 16-bit → 8-bit 데이터 패킹 (Little Endian)
- `mipi_csi2_tx_fsm.v` - MIPI CSI-2 TX FSM (FS/LS/Payload/FE)
- `frame_generator.v` - 가상 프레임 생성기 (16줄 반복)
- `top.v` - Top 통합 모듈

## 🎯 작업 요청 예시

```
"claude-workspace/fpga-draft/rtl/에 data_pack_16to8.v 모듈 작성해줘.
16-bit 데이터를 Little Endian 방식으로 8-bit 2개로 변환.
AXI4-Stream 인터페이스 사용, TVALID/TREADY 핸드셰이크 구현."
```

## ✅ 검토 후 이동 위치

`../../fpga/rtl/`

## 📋 체크리스트

- [ ] Verilog 문법 확인
- [ ] AXI4-Stream 인터페이스 정확성
- [ ] Endian 변환 로직 검증
- [ ] 시뮬레이션 통과
- [ ] 주석 충분
