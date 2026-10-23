# dv-team — `dv init` 팀 공유판

`dv init` 한 번으로 Ubuntu/Debian 시스템과 설치된 개발 도구를 업데이트합니다.
개인 KscTool 저장소를 복제하지 않고 팀 전용 공개 저장소만 사용합니다.

## 설치와 실행

Ubuntu/Debian의 Bash에서 실행합니다. Git이 설치되어 있어야 합니다.
기존 `~/dv-team` 폴더가 있다면 덮어쓰지 말고 다른 위치를 사용하세요.

```bash
git clone https://github.com/ksc2320/dv-team.git "$HOME/dv-team"
bash "$HOME/dv-team/dv.sh" install
source ~/.bash_functions
dvteam init --dry-run
dvteam init
```

처음에는 `--dry-run`으로 실행할 명령을 확인합니다. 실제 시스템 업데이트는 `sudo` 암호와 패키지 설치 확인을 요청할 수 있습니다. 실행 중인 빌드나 업무가 끝난 뒤 실행해 주세요.

기존 `dv` 명령은 덮어쓰지 않습니다. `dv`가 없으면 `dv init`도 같은 명령으로 등록됩니다.
설치 경로를 셸에 등록하므로 설치 폴더는 이동하거나 지우지 않습니다.
영구 등록 없이 `bash dv.sh init --dry-run`, `bash dv.sh init`으로 실행해도 됩니다.

## 계속 최신판으로 쓰기

```bash
dvteam init
```

`init`, `ai`, `vim`은 이 도구 자체를 GitHub의 최신 `main`으로 먼저 갱신합니다.
갱신된 코드를 현재 셸에 적용한 뒤 PC 도구 업데이트를 이어서 실행합니다.
따로 갱신할 때만 `dvteam update`를 사용하면 됩니다.
1.1.0을 이미 설치한 팀원은 처음 한 번 `dvteam update`를 실행해 주세요.
압축 배포본을 쓰고 있다면 위의 Git 설치를 한 번 진행하세요. 이후 `dvteam update`로 받으면 됩니다.
설치 폴더에 직접 수정한 파일이 있으면 덮어쓰지 않고 중단합니다.
GitHub 접속이나 자체 갱신에 실패하면 PC 업데이트도 시작하지 않습니다.
`--dry-run`에서는 자체 갱신을 포함해 실제 다운로드·변경을 하지 않습니다.
터미널을 여는 것만으로는 네트워크에 접속하지 않습니다.

관리자는 변경을 검토하고 시험한 뒤 이 저장소에 커밋·푸시합니다. 새 변경은 그 뒤부터 팀원이 받을 수 있습니다.
GitHub Actions가 셸 문법과 모의 시험을 검사합니다. PC에서 실행되는 자동 게시 작업은 만들지 않습니다.

## 업데이트 범위

| 명령 | 동작 |
| --- | --- |
| `dv init` | apt 패키지 목록과 설치 패키지, Snap, AI 도구, Vim 플러그인 업데이트 |
| `dv ai` | 설치된 Claude, Claude 마켓·플러그인, Codex, Gemini 업데이트 |
| `dv vim` | `~/.vim/plugged`의 기존 Git 플러그인을 `pull --ff-only`로 업데이트 |
| `dv version` | 배포본 버전 확인 |
| `dvteam update` | 공개 GitHub 저장소에서 도구 자체 업데이트 |

업데이트 명령은 모두 `--dry-run`을 지원합니다. 없는 도구는 새로 설치하지 않습니다.
Vim 플러그인에 로컬 수정이 있거나 특정 커밋으로 고정돼 있으면 건너뜁니다.
Claude 플러그인은 설치된 범위와 프로젝트 경로를 유지합니다. Python 3이 필요합니다.
Codex는 `codex update`를 지원하는 설치본이 필요합니다. Gemini는 npm 설치본을 대상으로 합니다.
다른 방식으로 설치한 도구에서 업데이트가 실패하면 해당 도구의 설치 방식에 맞춰 수동 업데이트합니다.
실패한 항목이 있으면 마지막에 실패를 알리고 종료 코드 1을 반환합니다.

## 개인정보와 원본의 차이

이 배포본에는 개인 설정, 비밀번호, API 키, 인증 파일, 개인 dotfiles와 메모리가 들어 있지 않습니다.
GitHub 배포 주소는 누구나 읽을 수 있는 공개 주소입니다. 저장소에 사내 자료나 개인 설정을 추가하지 마세요.
기존 개인 `dv init`의 저장소 자동 커밋·푸시, 개인 패치판 빌드, AP 포트 소유권 변경, 개인 환경 검진은 제외했습니다.
비밀번호를 파일에 저장하지 않습니다. 도구 업데이트는 각 PC의 기존 인증과 패키지 서버를 이용합니다.
배포본 자체에 사용량 수집이나 개인 파일 업로드 기능은 없습니다. 자체 업데이트 때 공개 GitHub 저장소에 접속합니다.

참고: [Codex CLI 공식 안내](https://learn.chatgpt.com/docs/codex/cli), [Claude Code 공식 설치 안내](https://code.claude.com/docs/en/setup).

_작성: Codex / 최종 갱신: 2026-10-23_
