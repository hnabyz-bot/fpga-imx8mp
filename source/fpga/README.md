# FPGA Source Code

FPGA(Xilinx Artix-7 XC7A35T) 관련 소스 코드 및 IP 설정

## 📁 폴더 구조

```
fpga/
├── rtl/          Verilog/VHDL RTL 코드
├── ip/           Vivado IP 설정 파일 (TCL 스크립트)
├── constraints/  제약 파일 (XDC)
└── sim/          테스트벤치 및 시뮬레이션
```

## 📝 주요 모듈

### rtl/
- `data_pack_16to8.v` - 16-bit → 8-bit 데이터 패킹 모듈
- `mipi_csi2_tx_fsm.v` - MIPI CSI-2 TX FSM
- `frame_generator.v` - 가상 프레임 생성 (16줄 반복)
- `top.v` - Top 모듈

### ip/
- `mipi_csi2_tx_setup.tcl` - MIPI CSI-2 TX Subsystem IP 설정

### constraints/
- `pins.xdc` - 핀 맵핑
- `timing.xdc` - 타이밍 제약

### sim/
- `tb_data_pack.v` - 데이터 패킹 테스트벤치
- `tb_fsm.v` - FSM 테스트벤치

## 🎯 개발 가이드

문서: [agent-guide/agent-prompts.md](../agent-guide/agent-prompts.md) 참조
