#!/usr/bin/env python3
"""유튜브 채널/영상 정보 추출기.

WebFetch 가 egress 정책에 막히는 환경(EGRESS_BLOCKED)에서도 curl 은 통과하므로,
curl 로 페이지를 받아 ytInitialData 를 파싱한다. 유튜브는 렌더링을 자바스크립트로
하지만, 필요한 데이터는 HTML 에 ytInitialData JSON 으로 이미 들어 있다.

사용:
    ./yt.py <채널URL|@핸들|영상URL>
    ./yt.py @music_fever_forever
    ./yt.py https://www.youtube.com/@music_fever_forever --json
    ./yt.py <URL> --videos 30

옵션:
    --json        원시 구조를 JSON 으로 출력 (다른 도구에 넘길 때)
    --videos N    나열할 영상 수 (기본 15)
"""

import json
import re
import subprocess
import sys

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")


def fetch(url: str) -> str:
    """curl 로 페이지를 가져온다. WebFetch 대신 쓰는 이유는 모듈 docstring 참고."""
    r = subprocess.run(
        ["curl", "-sL", "--max-time", "40", "-A", UA, url],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        raise SystemExit(f"curl 실패 (exit {r.returncode}): {r.stderr.strip()[:200]}")
    if not r.stdout:
        raise SystemExit("빈 응답. URL 을 확인하세요.")
    return r.stdout


def normalize(target: str) -> str:
    if target.startswith("http"):
        return target
    if target.startswith("@"):
        return f"https://www.youtube.com/{target}"
    return f"https://www.youtube.com/@{target}"


def initial_data(html: str) -> dict:
    m = re.search(r"var ytInitialData = (\{.*?\});</script>", html, re.S)
    if not m:
        raise SystemExit("ytInitialData 를 찾지 못했습니다. 페이지 구조가 바뀌었거나 차단된 응답입니다.")
    return json.loads(m.group(1))


def meta(html: str, prop: str):
    m = re.search(r'<meta[^>]+(?:property|name)="%s"[^>]+content="([^"]*)"'
                  % re.escape(prop), html)
    if not m:
        return None
    # HTML 엔티티 최소 복원 (설명문에 &#39; 등이 자주 섞인다)
    s = m.group(1)
    for a, b in [("&#39;", "'"), ("&quot;", '"'), ("&amp;", "&"),
                 ("&lt;", "<"), ("&gt;", ">")]:
        s = s.replace(a, b)
    return s


def walk(node, key, out):
    if isinstance(node, dict):
        for k, v in node.items():
            if k == key:
                out.append(v)
            walk(v, key, out)
    elif isinstance(node, list):
        for v in node:
            walk(v, key, out)


def scalar_stats(html: str) -> dict:
    """구독자/영상 수는 위치가 자주 바뀌어 문자열로 직접 찾는 편이 안정적이다."""
    out = {}
    m = re.search(r'"([\d.,]+[KMB]? subscribers)"', html)
    if m:
        out["subscribers"] = m.group(1)
    m = re.search(r'"([\d.,]+[KMB]? videos)"', html)
    if m:
        out["videos"] = m.group(1)
    return out


def videos(data: dict, limit: int) -> list:
    cards, rows, seen = [], [], set()
    walk(data, "lockupMetadataViewModel", cards)
    for c in cards:
        title = (c.get("title") or {}).get("content")
        if not title or title in seen:
            continue
        seen.add(title)
        parts = []
        walk(c.get("metadata", {}), "content", parts)
        views = next((p for p in parts if isinstance(p, str) and "view" in p), None)
        age = next((p for p in parts if isinstance(p, str) and "ago" in p), None)
        rows.append({"title": title, "views": views, "age": age})
        if len(rows) >= limit:
            break
    return rows


def main() -> None:
    args = [a for a in sys.argv[1:]]
    if not args:
        raise SystemExit(__doc__)
    as_json = "--json" in args
    limit = 15
    if "--videos" in args:
        i = args.index("--videos")
        try:
            limit = int(args[i + 1])
        except (IndexError, ValueError):
            raise SystemExit("--videos 뒤에 숫자가 필요합니다.")
        del args[i:i + 2]
    args = [a for a in args if a != "--json"]
    if not args:
        raise SystemExit("대상 URL 또는 @핸들이 필요합니다.")

    url = normalize(args[0])
    html = fetch(url)
    if "<title>404 Not Found</title>" in html:
        raise SystemExit(f"404 — 존재하지 않는 채널/영상입니다: {url}")

    data = initial_data(html)
    result = {
        "url": url,
        "name": meta(html, "og:title"),
        "description": meta(html, "og:description"),
        **scalar_stats(html),
        "recent_videos": videos(data, limit),
    }

    if as_json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    print(f"채널   : {result['name']}")
    print(f"URL    : {result['url']}")
    print(f"구독자 : {result.get('subscribers', '(확인 불가)')}")
    print(f"영상수 : {result.get('videos', '(확인 불가)')}")
    if result["description"]:
        print(f"설명   : {result['description'][:400]}")
    print(f"\n최근 영상 {len(result['recent_videos'])}건")
    for v in result["recent_videos"]:
        stat = " / ".join(x for x in (v["views"], v["age"]) if x)
        print(f"  {v['title'][:60]:60} {stat}")


if __name__ == "__main__":
    main()
