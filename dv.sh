#!/usr/bin/env bash
# dv-team — 팀 공용 개발 도구 업데이트 v1.2.0
# 사용법: bash dv.sh install → source ~/.bash_functions → dv init
# 개인 dotfiles, 인증정보, 저장소 자동 커밋, 장비 설정은 포함하지 않는다.

DVT_VERSION='1.2.0'

_dvt_run() {
    printf '  ▸'; printf ' %q' "$@"; printf '\n'
    if (( _dvt_dry )); then return 0; fi
    if "$@"; then
        printf '  ✔ 완료\n'
    else
        printf '  ✘ 실패: 위 오류를 확인하세요.\n' >&2
        _dvt_failed=1
    fi
}

_dvt_install() {
    local self line target
    self=$(realpath -- "${BASH_SOURCE[0]}") || return 1
    mkdir -p "$HOME/.devtools/dv-team" || return 1
    if [[ ! -e "$HOME/.devtools/dv-team/config" ]]; then
        printf '# dv-team: 개인 인증정보를 이 파일에 넣지 마세요.\n' > "$HOME/.devtools/dv-team/config" || return 1
    fi
    printf -v line '[ -f %q ] && source %q' "$self" "$self"
    target="$HOME/.bash_functions"
    grep -qxF -- "$line" "$target" 2>/dev/null || printf '\n%s\n' "$line" >> "$target" || return 1
    line='[ -f "$HOME/.bash_functions" ] && source "$HOME/.bash_functions"'
    target="$HOME/.bashrc"
    grep -qF '.bash_functions' "$target" 2>/dev/null || printf '\n%s\n' "$line" >> "$target" || return 1
    printf '✔ 설치 완료. 설치 폴더는 그대로 보관하세요.\nsource ~/.bash_functions\n'
    printf '기존 dv가 있으면 유지합니다. 이 도구는 dvteam init 으로도 실행할 수 있습니다.\n'
}

_dvt_update() {
    local self directory root origin status branch
    self=$(realpath -- "${BASH_SOURCE[0]}") || return 1
    directory=${self%/*}
    command -v git >/dev/null 2>&1 || { printf 'git이 필요합니다.\n' >&2; return 1; }
    root=$(git -C "$directory" rev-parse --show-toplevel) || return 1
    if [[ $root != "$directory" ]]; then
        printf '독립 Git 설치본에서만 업데이트할 수 있습니다. README의 git clone 설치를 이용하세요.\n' >&2
        return 1
    fi
    origin=$(git -C "$directory" remote get-url origin) || return 1
    case "$origin" in
        https://github.com/ksc2320/dv-team.git|git@github.com:ksc2320/dv-team.git) ;;
        *) printf '공식 dv-team 저장소가 아닙니다. 업데이트를 중단합니다.\n' >&2; return 1 ;;
    esac
    branch=$(git -C "$directory" symbolic-ref --short -q HEAD) || return 1
    status=$(git -C "$directory" status --porcelain) || return 1
    if [[ $branch != main || -n $status ]]; then
        printf 'main 브랜치의 수정 없는 설치본만 업데이트합니다. 로컬 변경은 그대로 보존했습니다.\n' >&2
        return 1
    fi
    _dvt_run git -C "$directory" pull --ff-only origin main
    (( !_dvt_failed )) || return 1
    if (( !_dvt_dry )); then
        source "$self" || return 1
        printf '✔ dv-team v%s 적용 완료\n' "$DVT_VERSION"
    fi
}

_dvt_system() {
    if command -v apt-get >/dev/null 2>&1; then
        _dvt_run sudo apt-get update
        if (( !_dvt_failed )); then _dvt_run sudo apt-get upgrade --with-new-pkgs; fi
    else
        printf '  - apt-get 없음: 시스템 업데이트 생략 (Ubuntu/Debian 대상)\n'
    fi
    if command -v snap >/dev/null 2>&1; then _dvt_run sudo snap refresh; fi
}

_dvt_ai() {
    if command -v claude >/dev/null 2>&1; then
        _dvt_run claude update
        _dvt_run claude plugin marketplace update
        if (( _dvt_dry )); then
            printf '  ▸ 설치된 Claude 플러그인을 원래 범위와 프로젝트에서 업데이트\n'
        elif command -v python3 >/dev/null 2>&1; then
            _dvt_run python3 - <<'PY'
import json
import subprocess

result = subprocess.run(["claude", "plugin", "list", "--json"], check=True, capture_output=True, text=True)
failed = False
for plugin in json.loads(result.stdout):
    scope = plugin["scope"]
    directory = plugin.get("projectPath") if scope in ("project", "local") else None
    if scope in ("project", "local") and not directory:
        print("플러그인 프로젝트 경로 없음: 업데이트 생략", flush=True)
        failed = True
        continue
    try:
        completed = subprocess.run(["claude", "plugin", "update", plugin["id"], "-s", scope], cwd=directory)
        failed |= completed.returncode != 0
    except OSError as error:
        print(f"플러그인 업데이트 실패: {error}", flush=True)
        failed = True
raise SystemExit(int(failed))
PY
        else
            printf '  ✘ python3 없음: Claude 플러그인 업데이트 불가\n' >&2
            _dvt_failed=1
        fi
    else
        printf '  - Claude 미설치: 생략\n'
    fi
    if command -v codex >/dev/null 2>&1; then _dvt_run codex update; else printf '  - Codex 미설치: 생략\n'; fi
    if command -v gemini >/dev/null 2>&1; then
        if command -v npm >/dev/null 2>&1; then
            _dvt_run npm install -g @google/gemini-cli@latest
        else
            printf '  ✘ npm 없음: Gemini 업데이트 불가\n' >&2
            _dvt_failed=1
        fi
    else
        printf '  - Gemini 미설치: 생략\n'
    fi
}

_dvt_vim() {
    local directory status
    if ! command -v git >/dev/null 2>&1; then printf '  - git 없음: Vim 플러그인 생략\n'; return; fi
    for directory in "$HOME"/.vim/plugged/*/; do
        [[ -d "$directory/.git" || -f "$directory/.git" ]] || continue
        git -C "$directory" symbolic-ref -q HEAD >/dev/null || continue
        if ! status=$(git -C "$directory" status --porcelain); then
            printf '  ✘ Vim 플러그인 상태 확인 실패\n' >&2
            _dvt_failed=1
            continue
        fi
        if [[ -n $status ]]; then
            printf '  - 로컬 수정이 있는 Vim 플러그인: 업데이트 생략\n'
            continue
        fi
        _dvt_run git -C "$directory" pull --ff-only
    done
}

_dvt_work() {
    local command=$1
    if [[ $command == init ]]; then _dvt_system; fi
    if [[ $command == init || $command == ai ]]; then _dvt_ai; fi
    if [[ $command == init || $command == vim ]]; then _dvt_vim; fi
    if (( _dvt_failed )); then printf '✘ 일부 업데이트 실패. 위 오류를 확인하세요.\n' >&2; return 1; fi
    if (( _dvt_dry )); then printf '✔ 실행 예정 항목 표시 완료 (변경 없음)\n'; else printf '✔ 업데이트 완료 (미설치·수정 중 항목은 생략)\n'; fi
}

_dvt_main() {
    local command=${1:-help} _dvt_dry=0 _dvt_failed=0
    if (( $# )); then shift; fi
    case "$command" in
        install) (( $# == 0 )) || return 2; _dvt_install; return ;;
        version|-V|--version) printf 'dv-team v%s\n' "$DVT_VERSION"; return ;;
        help|-h|--help)
            printf '%s\n' 'dv-team — Ubuntu/Debian 개발 도구 업데이트' \
                '  install                  현재 파일을 Bash에 등록 (최초 1회)' \
                '  update [--dry-run]       GitHub에서 dv-team 자체 업데이트' \
                '  init [--dry-run]         자체 갱신 후 시스템 + AI + Vim 업데이트' \
                '  ai [--dry-run]           자체 갱신 후 설치된 Claude·Codex·Gemini 업데이트' \
                '  vim [--dry-run]          자체 갱신 후 기존 Vim 플러그인 업데이트' \
                '  version | help           버전 / 도움말' \
                'sudo는 필요할 때 직접 암호를 묻습니다. 기존 dv가 있으면 dvteam을 쓰세요.'
            return ;;
        init|ai|vim|update) ;;
        *) printf '알 수 없는 명령: %s\n' "$command" >&2; return 2 ;;
    esac
    if (( $# )); then
        if [[ $# == 1 && $1 == --dry-run ]]; then _dvt_dry=1; else printf '지원 옵션: --dry-run\n' >&2; return 2; fi
    fi
    printf '\033[38;5;153m[dv-team v%s] %s\033[0m\n' "$DVT_VERSION" "$command"
    if [[ $command == update ]]; then _dvt_update; return; fi
    _dvt_update || return 1
    _dvt_work "$command"
}

_dvt_register() {
    alias dvteam='_dvt_main'
    if ! alias dv >/dev/null 2>&1 && ! type dv >/dev/null 2>&1; then alias dv='_dvt_main'; fi
}

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    _dvt_register
else
    _dvt_main "$@"
fi
