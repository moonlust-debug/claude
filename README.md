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
사용자 설정 병합 → 개인·원격 스킬 설치 → OmniRoute 설치를 순서대로 하고, 이미
되어 있는 단계는 건너뛴다. 여러 번 돌려도 안전하다. 옵션은 `./setup.sh --help` 참고.

## claude-mem

4단계가 [claude-mem](https://github.com/thedotmack/claude-mem) 플러그인을
사용자 설정(`~/.claude/settings.json`)에 등록한다. 세션 간 기억을 쌓는 플러그인이라
이 저장소 안에서만 켜면 쓸모가 없어서 전역으로 넣는다. `claude` 를 다시 띄우면
마켓플레이스에서 받아 붙는다.

스킬(`mem-search`, `standup`, `timeline-report` 등 20개)은 플러그인이 함께
제공한다. `npx skills add` 로 스킬만 깔면 마크다운만 오고 기억을 쌓는 훅·워커·
SQLite 가 빠져서 조회할 것이 없다. 같은 이유로 `npm install -g claude-mem` 도
SDK 만 깔리므로 쓰지 않는다.

## Headroom

4단계가 [Headroom](https://github.com/headroomlabs-ai/headroom) CLI 를 깔고,
5단계가 `headroom` 이 실제로 잡힐 때만 플러그인(`headroom@headroom-marketplace`)을
켠다. 플러그인 훅이 SessionStart 와 모든 Bash 호출마다 `headroom` 을 부르기
때문에, CLI 없이 플러그인만 켜면 매 도구 호출에 실패하는 훅이 붙는다.

**Headroom 은 스킬이 아니다.** 저장소에 `SKILL.md` 가 하나도 없다. 스킬 레지스트리에
`headroom` 이라는 이름으로 올라온 것들은 공식이 아닌 제3자 사본이다.

설치는 CLI·플러그인까지다. 압축은 켜야 동작한다:

```sh
headroom deploy        # 로컬 배포 + 에이전트 설정 (또는 headroom wrap claude)
headroom doctor        # 라우팅이 실제로 걸렸는지 확인
```

extras 는 `[proxy,code]` 로 깐다 — README 가 `[proxy]` 를 "most common install" 로
부르고, `[code]` 가 간판 기능인 tree-sitter AST 압축이다. `[all]` 은 `[ml]` 을 통해
torch 를 끌어와 수 GB 가 되므로 부트스트랩에서는 피한다. 필요하면
`uv tool install --python 3.13 "headroom-ai[all]"` 로 덮어쓰면 된다.

## OmniRoute

6단계는 [OmniRoute](https://github.com/diegosouzapw/OmniRoute) 게이트웨이를
**설치만** 한다. 라우팅은 켜지 않는다 — `ANTHROPIC_BASE_URL` 을 전역으로 돌리면
평소 쓰는 계정의 트래픽까지 제3자 프로바이더로 새기 때문이다. 쓸 때만 켠다:

```sh
omniroute                                                   # 한 셸에서 게이트웨이
ANTHROPIC_BASE_URL=http://localhost:20128/v1 claude          # 다른 셸에서
```

> **알고 쓸 것.** Socket.dev 가 `omniroute@3.8.5` 를 공급망 점수 48 /
> "AI-detected potential malware" 로 표시했다 — 루트 CA 설치, DNS 조작, MITM 서버,
> 키체인 자격증명 수집 주장. [issues/2863](https://github.com/diegosouzapw/OmniRoute/issues/2863)
> 은 메인테이너 응답 없이 열려 있고, CVE-2026-49352 가 이 프로젝트에 할당돼 있다.
> 빼려면 `./setup.sh --skip-omniroute`, 이미 깔았으면 `npm uninstall -g omniroute`.

Windows 는 Claude Code 만 PowerShell 에서 먼저 깔고(`irm https://claude.ai/install.ps1 | iex`)
Git Bash 에서 `./setup.sh` 를 돌린다.

자세한 구조는 [AGENTS.md](AGENTS.md) 참고.
