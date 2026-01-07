# Source Code Directory

실제 구현 코드를 위한 디렉토리

## 📁 구조

```
source/
├── fpga/         FPGA (Xilinx Artix-7) 관련 코드
│   ├── rtl/      Verilog/VHDL RTL
│   ├── ip/       Vivado IP 설정
│   ├── constraints/ XDC 제약 파일
│   └── sim/      테스트벤치
│
└── imx8mp/       i.MX8MP 관련 코드
    ├── device-tree/ Device Tree 설정
    ├── scripts/  스크립트 (캡처, 검증)
    └── drivers/  드라이버 (필요 시)
```

## 🚀 시작하기

### FPGA 개발
1. [fpga/README.md](fpga/README.md) 참조
2. Task 가이드: [agent-guide/agent-prompts.md](../agent-guide/agent-prompts.md)
3. 5일 계획: [agent-guide/todo-list-5days.md](../agent-guide/todo-list-5days.md)

### i.MX8MP 개발
1. [imx8mp/README.md](imx8mp/README.md) 참조
2. Device Tree 가이드: [agent-guide/agent-prompts.md](../agent-guide/agent-prompts.md#task-2-1-device-tree-작성)

## 📚 참고 문서

프로젝트 문서는 [agent-guide/](../agent-guide/) 폴더 참조
