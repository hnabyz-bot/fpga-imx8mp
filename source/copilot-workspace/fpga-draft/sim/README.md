# MIPI CSI-2 TX Testbench Structure

## 설계 목표
FPGA(Artix-7) → i.MX8MP MIPI CSI-2 4-Lane 전송
- 입력: 256×16-bit
- 출력: 512×8-bit RAW8 (Little Endian)
- 프레임: 16 lines

## 구조

### sim/ (메인 검증)
- **tb_top_with_rx.v** - TX→RX 통합 검증 (Protocol Layer)
- **mipi_csi2_rx_bfm.v** - RX 검증 모델 (ECC/CRC)

### sim/unit-tests/ (모듈별 검증)
- **tb_data_pack_16to8.v** - 16bit→8bit Little Endian 변환
- **tb_frame_generator.v** - 프레임 데이터 생성
- **tb_mipi_fsm.v** - MIPI CSI-2 패킷 FSM

### rtl/ (설계 모듈 - TB 검증 후 작성)
- data_pack_16to8.v
- frame_generator.v
- mipi_fsm.v

## TDD 순서
1. ✅ TB 작성 완료
2. ⏳ RTL 모듈 작성 대기
3. ⏳ TB로 RTL 검증
4. ⏳ 통합 검증
