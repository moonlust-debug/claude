# claude

moonlust-debug 의 Claude Code 개인 설정 보관소. 여러 머신과 웹/원격 세션에 걸쳐
같은 환경을 재현하기 위한 설치 스크립트·훅·개인 스킬·권한 설정이 들어 있다.

## 새 머신 설치

```sh
git clone https://github.com/moonlust-debug/claude.git ~/claude
~/claude/setup.sh
```

또는 사본 없이 한 줄로:

```sh
curl -fsSL https://raw.githubusercontent.com/moonlust-debug/claude/main/setup.sh | bash
```

`setup.sh` 는 Claude Code 설치 확인 → 저장소 확보 → `~/.claude/skills` 링크 →
사용자 설정 병합 → 개인·원격 스킬 설치를 순서대로 하고, 이미 되어 있는 단계는
건너뛴다. 여러 번 돌려도 안전하다. 옵션은 `./setup.sh --help` 참고.

Windows 는 Claude Code 만 PowerShell 에서 먼저 깔고(`irm https://claude.ai/install.ps1 | iex`)
Git Bash 에서 `./setup.sh` 를 돌린다.

자세한 구조는 [AGENTS.md](AGENTS.md) 참고.
