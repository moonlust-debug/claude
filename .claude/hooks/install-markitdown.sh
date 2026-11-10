#!/usr/bin/env bash
# SessionStart hook: markitdown 스킬이 부르는 Microsoft MarkItDown(CLI + Python 패키지).
#
# 스킬(install-skills.sh)은 사용법 문서일 뿐이라 실제 변환기는 따로 깔아야 한다.
# 웹 세션은 매번 새 컨테이너라 매 시작마다 확인하고, 이미 있으면 바로 끝낸다.
# [all] extra 는 PDF·docx·pptx·xlsx 등 포맷별 의존성을 함께 받는다.
set -uo pipefail

LOG="${TMPDIR:-/tmp}/install-markitdown.log"

if command -v markitdown >/dev/null 2>&1 && python3 -c 'import markitdown' >/dev/null 2>&1; then
  exit 0
fi

echo "markitdown: installing…"
: >"$LOG"

# CLI 만이 아니라 `from markitdown import MarkItDown` 도 되어야 하므로 uv tool 이 아닌 pip 로 시스템 파이썬에 넣는다.
pip3 install --quiet --break-system-packages -U 'markitdown[all]' >>"$LOG" 2>&1 ||
  pip3 install --quiet -U 'markitdown[all]' >>"$LOG" 2>&1

if command -v markitdown >/dev/null 2>&1; then
  echo "markitdown: ready ($(markitdown --version 2>/dev/null))."
else
  echo "markitdown: could not install. See $LOG"
fi

exit 0
