# i.MX8MP Draft - Device Tree 작업 공간 (Claude)

Claude가 Device Tree 파일을 작성하는 폴더입니다.

## 📝 작업 예정 파일

- `imx8mp-mipi-csi2.dts` - MIPI CSI-2 및 ISI 설정
- `imx8mp-overlay.dtso` - Device Tree Overlay (필요시)

## 🎯 작업 요청 예시

```
"claude-workspace/imx8mp-draft/device-tree/에 imx8mp-mipi-csi2.dts 작성해줘.
MIPI CSI-2 4-Lane 설정, ISI 512x16 해상도, stride=512 (64-byte 정렬).
agent-guide/mipi-project-plan.md 참조."
```

## ✅ 검토 후 이동 위치

`../../imx8mp/device-tree/`

## 📋 체크리스트

- [ ] DT 문법 확인 (dtc)
- [ ] mipi_csi 노드: data-lanes, clock-lanes
- [ ] isi 노드: width, height, stride
- [ ] 64-byte 정렬 확인
- [ ] 엔드포인트 연결 정확성
