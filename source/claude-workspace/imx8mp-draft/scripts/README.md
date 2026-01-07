# i.MX8MP Draft - Scripts 작업 공간 (Claude)

Claude가 스크립트를 작성하는 폴더입니다.

## 📝 작업 예정 파일

- `check_fpga_done.sh` - FPGA Configuration DONE 상태 확인
- `setup_isi.sh` - ISI 초기화 스크립트
- `capture.sh` - v4l2-ctl 데이터 캡처
- `verify.py` - 데이터 무결성 검증 (Little Endian 복원)

## 🎯 작업 요청 예시

```
"claude-workspace/imx8mp-draft/scripts/에 verify.py 작성해줘.
capture.raw 파일을 읽어서 RAW8을 16-bit Little Endian으로 복원.
기대값과 비교해서 무결성 100% 검증.
agent-guide/agent-prompts.md의 검증 로직 참조."
```

## ✅ 검토 후 이동 위치

`../../imx8mp/scripts/`

## 📋 체크리스트

- [ ] Bash 문법 확인 (shellcheck)
- [ ] Python 문법 확인
- [ ] 실행 권한 설정 (chmod +x)
- [ ] 에러 처리 충분
- [ ] 로컬 테스트 통과
- [ ] 주석 및 사용법 설명
