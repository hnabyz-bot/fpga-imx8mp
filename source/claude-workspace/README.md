# Claude Workspace - AI 작업 전용 영역

## 🎯 목적

이 폴더는 **Claude AI가 코드를 작성하는 전용 공간**입니다.  
작성된 코드를 검토 후, 사용자가 수동으로 최종 위치로 이동시킵니다.

---

## 📁 폴더 구조

```
claude-workspace/
├── fpga-draft/           # FPGA 코드 작업 공간
│   ├── rtl/              # RTL 코드 draft
│   ├── ip/               # IP 설정 draft
│   ├── constraints/      # 제약 파일 draft
│   └── sim/              # 테스트벤치 draft
│
├── imx8mp-draft/         # i.MX8MP 코드 작업 공간
│   ├── device-tree/      # Device Tree draft
│   ├── scripts/          # 스크립트 draft
│   └── drivers/          # 드라이버 draft
│
├── integration-test/     # 통합 테스트 파일
│   └── test-logs/        # 테스트 로그 보관
│
└── README.md             # 이 파일
```

---

## 🔄 워크플로우

### 1. Claude 작업 단계
```
사용자 요청 → Claude가 draft 폴더에 코드 작성 → 완료 알림
```

**예시**:
```
📝 Task: "data_pack_16to8.v 모듈 작성"
   ↓
✅ 생성: claude-workspace/fpga-draft/rtl/data_pack_16to8.v
   ↓
💬 알림: "코드 작성 완료. 검토 후 승인해주세요."
```

### 2. 사용자 검토 단계
```
Draft 코드 확인 → 시뮬레이션/테스트 → 문제 있으면 수정 요청
```

**체크리스트**:
- [ ] 코드 문법 확인
- [ ] 시뮬레이션 통과 (FPGA)
- [ ] 실행 테스트 (i.MX8MP)
- [ ] 주석 및 문서화 충분
- [ ] 코딩 스타일 일관성

### 3. 승인 및 이동 단계
```
승인 → 사용자가 수동으로 최종 위치로 이동 → Git 커밋
```

**이동 예시**:
```powershell
# FPGA RTL 파일 이동
Move-Item claude-workspace/fpga-draft/rtl/data_pack_16to8.v source/fpga/rtl/

# Device Tree 파일 이동
Move-Item claude-workspace/imx8mp-draft/device-tree/*.dts source/imx8mp/device-tree/

# Git 커밋
git add source/fpga/rtl/data_pack_16to8.v
git commit -m "Add data packing module (Claude-assisted, reviewed)"
```

---

## ⚡ 빠른 명령어

### Claude에게 작업 요청
```
"claude-workspace/fpga-draft/rtl/ 에 data_pack_16to8.v 작성해줘"
"claude-workspace/imx8mp-draft/scripts/ 에 capture.sh 작성해줘"
```

### 파일 이동 (승인 후)
```powershell
# 단일 파일
Move-Item claude-workspace/fpga-draft/rtl/module.v source/fpga/rtl/

# 여러 파일
Get-ChildItem claude-workspace/fpga-draft/rtl/*.v | Move-Item -Destination source/fpga/rtl/

# 폴더 전체
Move-Item claude-workspace/fpga-draft/ip/* source/fpga/ip/
```

### Draft 정리
```powershell
# 이동 완료된 파일 삭제
Remove-Item claude-workspace/fpga-draft/rtl/data_pack_16to8.v

# 전체 정리 (주의!)
Remove-Item -Recurse claude-workspace/*/
```

---

## 🎨 상태 표시 규칙

### 파일명 접두사 (선택 사항)
- `DRAFT-` : 작성 중
- `REVIEW-` : 검토 필요
- `APPROVED-` : 승인됨, 이동 대기

**예시**:
```
DRAFT-data_pack_16to8.v       → 작성 중
REVIEW-data_pack_16to8.v      → 검토 요청
APPROVED-data_pack_16to8.v    → 이동 준비 완료
```

### 상태 파일
각 draft 폴더에 `STATUS.md` 생성 가능:
```markdown
# 작업 상태

## 완료
- [x] data_pack_16to8.v (이동 완료: 2026-01-07)

## 검토 중
- [ ] mipi_csi2_tx_fsm.v

## 작업 중
- [ ] frame_generator.v
```

---

## 🔒 Git 관리

### .gitignore 설정 (선택)

**옵션 1: Draft를 Git에 포함**
- 장점: 모든 히스토리 보존, Claude 작업 과정 추적
- 단점: 저장소 크기 증가

**옵션 2: Draft를 Git에서 제외**
```gitignore
# .gitignore에 추가
source/claude-workspace/fpga-draft/
source/claude-workspace/imx8mp-draft/
source/claude-workspace/integration-test/test-logs/

# README.md는 포함
!source/claude-workspace/README.md
```

**추천**: 옵션 1 (Claude 작업 히스토리 보존)

---

## 📋 작업 체크리스트 템플릿

### FPGA 모듈 작업
```markdown
- [ ] Claude가 rtl/ 폴더에 코드 작성
- [ ] 시뮬레이션 테스트벤치 작성
- [ ] Vivado에서 문법 체크
- [ ] 시뮬레이션 실행 및 파형 확인
- [ ] 코드 리뷰 (주석, 스타일)
- [ ] source/fpga/rtl/로 이동
- [ ] Git 커밋
```

### i.MX8MP 스크립트 작업
```markdown
- [ ] Claude가 scripts/ 폴더에 스크립트 작성
- [ ] Bash 문법 체크 (shellcheck)
- [ ] 테스트 환경에서 실행 테스트
- [ ] 에러 처리 확인
- [ ] 권한 설정 확인 (chmod +x)
- [ ] source/imx8mp/scripts/로 이동
- [ ] Git 커밋
```

---

## 💡 Claude 전문가 팁

### 1. 상세한 컨텍스트 제공
```
"claude-workspace/fpga-draft/rtl/에 16-bit를 8-bit로 변환하는 모듈 작성.
Little Endian 방식, AXI4-Stream 인터페이스 사용, TVALID/TREADY 핸드셰이크 구현"
```

### 2. 문서 참조 요청
```
"agent-guide/mipi-project-plan.md를 참조해서 MIPI FSM 모듈 작성"
```

### 3. 점진적 개선
```
claude-workspace/fpga-draft/rtl/
├── data_pack_16to8_v1.v      # 초기 버전
├── data_pack_16to8_v2.v      # 개선 버전
└── data_pack_16to8_final.v   # 최종 버전 (이동 대상)
```

### 4. 테스트 우선 개발
```
"먼저 테스트벤치를 sim/에 작성하고, 그 다음 RTL 모듈 작성"
```

### 5. 통합 테스트 로그
```
integration-test/test-logs/
├── 2026-01-07_fpga_simulation.log
├── 2026-01-08_imx8mp_capture.log
└── 2026-01-09_integration_test.log
```

---

## 🚀 Claude 작업 시작 가이드

### Step 1: 사전 준비
```
1. agent-guide/ 문서 숙지
2. 작업 목표 명확화
3. 출력 위치 확인: claude-workspace/XXX-draft/
```

### Step 2: 작업 요청
```
"claude-workspace/fpga-draft/rtl/에 다음 사양의 모듈 작성:
- 모듈명: data_pack_16to8
- 기능: 16-bit → 8-bit Little Endian 변환
- 인터페이스: AXI4-Stream
- 요구사항: agent-guide/agent-prompts.md 참조"
```

### Step 3: 검증
```powershell
# 파일 확인
code source/claude-workspace/fpga-draft/rtl/data_pack_16to8.v

# 문법 체크 (Vivado)
vivado -mode batch -source check_syntax.tcl

# 시뮬레이션
vsim -do "run -all; quit"
```

### Step 4: 승인 및 이동
```powershell
# 검증 완료 후 이동
Move-Item source/claude-workspace/fpga-draft/rtl/data_pack_16to8.v source/fpga/rtl/

# 커밋
git add source/fpga/rtl/data_pack_16to8.v
git commit -m "Add 16-to-8 bit packing module

- Claude-assisted development
- Little Endian conversion
- AXI4-Stream interface
- Verified with simulation"
git push
```

---

## 🎯 프로젝트별 작업 예시

### Day 1: 데이터 변환 모듈
```
요청: "claude-workspace/fpga-draft/rtl/에 data_pack_16to8.v 작성"
검증: Vivado 시뮬레이션
이동: source/fpga/rtl/
```

### Day 2: Device Tree
```
요청: "claude-workspace/imx8mp-draft/device-tree/에 
      MIPI CSI-2 및 ISI 설정 DTS 작성"
검증: dtc 컴파일 테스트
이동: source/imx8mp/device-tree/
```

### Day 3: MIPI FSM
```
요청: "claude-workspace/fpga-draft/rtl/에 
      MIPI CSI-2 TX FSM 모듈 작성 (FS/LS/Payload/FE)"
검증: 테스트벤치 시뮬레이션
이동: source/fpga/rtl/
```

### Day 4: 검증 스크립트
```
요청: "claude-workspace/imx8mp-draft/scripts/에 
      capture.sh와 verify.py 작성"
검증: 로컬 테스트 환경
이동: source/imx8mp/scripts/
```

### Day 5: 통합 테스트
```
실행: 모든 컴포넌트 통합 테스트
로그: integration-test/test-logs/에 저장
보고: 최종 검증 리포트 작성
```

---

## 🔍 Claude vs 다른 방식 비교

### Draft 폴더 사용 (Claude Workspace)
```
✅ 장점:
- 원본 코드 보호
- 실험적 작업 안전
- 단계적 검증 가능
- Git 히스토리 깔끔

❌ 단점:
- 수동 이동 필요
- 워크플로우 단계 증가
```

### 직접 작성 (기존 방식)
```
✅ 장점:
- 빠른 작업
- 단계 단순

❌ 단점:
- 원본 코드 직접 수정 위험
- 실패 시 복구 어려움
- 실험 부담
```

**전문가 추천**: Claude Workspace 사용 (안전성 우선)

---

## 📞 참고 문서

- **프로젝트 계획**: [../../agent-guide/mipi-project-plan.md](../../agent-guide/mipi-project-plan.md)
- **작업 지침**: [../../agent-guide/agent-prompts.md](../../agent-guide/agent-prompts.md)
- **5일 계획**: [../../agent-guide/todo-list-5days.md](../../agent-guide/todo-list-5days.md)
- **품질 검증**: [../../QUALITY-VERIFICATION-REPORT.md](../../QUALITY-VERIFICATION-REPORT.md)

---

## 🏆 Claude 워크스페이스 사용 원칙

1. **Safety First**: 원본 코드는 절대 직접 수정하지 않음
2. **Review Before Merge**: 모든 코드는 검토 후 이동
3. **Document Everything**: 작업 과정 문서화
4. **Test Driven**: 테스트 먼저, 구현은 나중
5. **Git History**: 모든 변경사항 추적 가능

---

**생성일**: 2026-01-07  
**목적**: 안전하고 체계적인 Claude AI 협업 워크플로우  
**버전**: 1.0
