// Telegram API 릴레이 — bun 의 CONNECT-터널 TLS 버그 우회용.
//
// 배경: 이 컨테이너의 이그레스 프록시는 커스텀 허용 도메인(api.telegram.org)을
// MITM 하지 않고 그대로 TCP 패스스루한다. bun 의 fetch 는 CONNECT 터널 위에서
// 직접 TLS 를 맺을 때 소켓이 리셋된다(ECONNRESET). curl 은 같은 경로에서 정상.
//
// 그래서 이 릴레이는 평문 HTTP 로 요청을 받아 curl 로 텔레그램에 중계하고
// 응답을 그대로 돌려준다. grammy 는 apiRoot 를 여기로 두면 localhost 평문만
// 상대하므로 bun 의 TLS 경로를 아예 타지 않는다.
//
// 사용: bun tg-relay.ts [port]        (기본 8081)

const PORT = Number(process.argv[2] ?? 8081);
const UPSTREAM = "https://api.telegram.org";

let seq = 0;

async function viaCurl(
  url: string,
  method: string,
  body: Uint8Array | null,
  contentType: string | null,
): Promise<{ status: number; body: Uint8Array; type: string }> {
  // 헤더는 -D 로 별도 파일에, 본문은 -o 로 별도 파일에 받는다.
  // (-i 로 합쳐 받으면 HTTP/2 응답에서 경계 파싱이 취약하고 바이너리도 깨진다)
  const tag = `${process.pid}-${seq++}`;
  const hFile = `/tmp/tg-relay-h-${tag}`;
  const bFile = `/tmp/tg-relay-b-${tag}`;

  const args = ["curl", "-sS", "--max-time", "120", "-X", method,
                "-D", hFile, "-o", bFile, url];
  if (contentType) args.push("-H", `Content-Type: ${contentType}`);
  if (body && body.byteLength > 0) args.push("--data-binary", "@-");

  try {
    const proc = Bun.spawn(args, {
      stdin: body && body.byteLength > 0 ? body : undefined,
      stdout: "pipe",
      stderr: "pipe",
    });
    const err = await new Response(proc.stderr).text();
    const rc = await proc.exited;

    if (rc !== 0) {
      return {
        status: 502,
        body: new TextEncoder().encode(
          JSON.stringify({ ok: false, error_code: 502, description: `relay: curl exit ${rc}: ${err.trim()}` }),
        ),
        type: "application/json",
      };
    }

    const head = await Bun.file(hFile).text().catch(() => "");
    // 마지막 상태줄이 최종 응답 (100 Continue / 리다이렉트 체인 대비)
    const codes = [...head.matchAll(/^HTTP\/[\d.]+\s+(\d{3})/gm)].map((m) => Number(m[1]));
    const status = codes.length ? codes[codes.length - 1] : 502;
    const ctMatch = head.match(/^content-type:\s*(.+)$/im);
    const type = ctMatch ? ctMatch[1].trim() : "application/json";
    const out = new Uint8Array(await Bun.file(bFile).arrayBuffer());
    return { status, body: out, type };
  } finally {
    Bun.spawn(["rm", "-f", hFile, bFile]);
  }
}

const server = Bun.serve({
  port: PORT,
  hostname: "127.0.0.1",
  idleTimeout: 0, // 롱폴링(getUpdates) 중 끊기지 않도록
  async fetch(req) {
    const u = new URL(req.url);
    const target = UPSTREAM + u.pathname + u.search;
    const body = req.method === "GET" || req.method === "HEAD"
      ? null
      : new Uint8Array(await req.arrayBuffer());
    const res = await viaCurl(target, req.method, body, req.headers.get("content-type"));
    return new Response(res.body, {
      status: res.status,
      headers: { "content-type": res.type },
    });
  },
});

console.error(`tg-relay: http://127.0.0.1:${server.port} → ${UPSTREAM} (curl 경유)`);
