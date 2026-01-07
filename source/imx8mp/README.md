# i.MX8MP Source Code

i.MX8MP 관련 Device Tree, 스크립트, 드라이버

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

## 🎯 개발 가이드

문서: [agent-guide/agent-prompts.md](../agent-guide/agent-prompts.md) 참조
