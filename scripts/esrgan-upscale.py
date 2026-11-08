#!/usr/bin/env python3
"""Real-ESRGAN x2 업스케일러 (CPU).

사용법:
    python3 scripts/esrgan-upscale.py <입력.png> <출력.png> [--size 1280x1920]

왜 이렇게 만들었나:
- codex 로 만든 이미지는 1024x1536 이라 1080x1920 표지에 그대로 늘리면 흐려진다.
  Lanczos+언샤프는 AI 피부 노이즈를 갈라진 잡티처럼 키워서 Real-ESRGAN 으로 바꿨다.
- 가중치(.pth)는 pickle 이라 임의 코드 실행 위험이 있다. 그래서 해시를 고정해 두고
  `torch.load(weights_only=True)` 로 텐서만 읽는다. 해시가 다르면 실행하지 않는다.
- 네트워크 구조(RRDBNet)는 외부 패키지(basicsr/realesrgan) 대신 여기 직접 둔다.
  그 패키지들은 설치가 무겁고, GitHub 릴리스는 웹 세션 프록시에서 막혀 있다.
- 의존성: torch(CPU), numpy, pillow. 없으면
  `pip install torch --index-url https://download.pytorch.org/whl/cpu` 로 설치한다.
"""
import argparse
import hashlib
import os
import sys
import urllib.request

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image

WEIGHTS_URL = "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x2.pth"
WEIGHTS_SHA256 = "c830d067d54fc767b9543a8432f36d91bc2de313584e8bbfe4ac26a47339e899"
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "esrgan")


class RDB(nn.Module):
    def __init__(s, nf=64, gc=32):
        super().__init__()
        s.conv1 = nn.Conv2d(nf, gc, 3, 1, 1)
        s.conv2 = nn.Conv2d(nf + gc, gc, 3, 1, 1)
        s.conv3 = nn.Conv2d(nf + 2 * gc, gc, 3, 1, 1)
        s.conv4 = nn.Conv2d(nf + 3 * gc, gc, 3, 1, 1)
        s.conv5 = nn.Conv2d(nf + 4 * gc, nf, 3, 1, 1)
        s.l = nn.LeakyReLU(0.2, True)

    def forward(s, x):
        x1 = s.l(s.conv1(x))
        x2 = s.l(s.conv2(torch.cat((x, x1), 1)))
        x3 = s.l(s.conv3(torch.cat((x, x1, x2), 1)))
        x4 = s.l(s.conv4(torch.cat((x, x1, x2, x3), 1)))
        return s.conv5(torch.cat((x, x1, x2, x3, x4), 1)) * 0.2 + x


class RRDB(nn.Module):
    def __init__(s, nf=64, gc=32):
        super().__init__()
        s.rdb1, s.rdb2, s.rdb3 = RDB(nf, gc), RDB(nf, gc), RDB(nf, gc)

    def forward(s, x):
        return s.rdb3(s.rdb2(s.rdb1(x))) * 0.2 + x


class RRDBNetX2(nn.Module):
    # x2 모델은 입력을 pixel_unshuffle(2) 해서 12채널로 넣는다.
    def __init__(s, nf=64, nb=23):
        super().__init__()
        s.conv_first = nn.Conv2d(12, nf, 3, 1, 1)
        s.body = nn.Sequential(*[RRDB(nf) for _ in range(nb)])
        s.conv_body = nn.Conv2d(nf, nf, 3, 1, 1)
        s.conv_up1 = nn.Conv2d(nf, nf, 3, 1, 1)
        s.conv_up2 = nn.Conv2d(nf, nf, 3, 1, 1)
        s.conv_hr = nn.Conv2d(nf, nf, 3, 1, 1)
        s.conv_last = nn.Conv2d(nf, 3, 3, 1, 1)
        s.l = nn.LeakyReLU(0.2, True)

    def forward(s, x):
        f = s.conv_first(F.pixel_unshuffle(x, 2))
        f = f + s.conv_body(s.body(f))
        f = s.l(s.conv_up1(F.interpolate(f, scale_factor=2, mode="nearest")))
        f = s.l(s.conv_up2(F.interpolate(f, scale_factor=2, mode="nearest")))
        return s.conv_last(s.l(s.conv_hr(f)))


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def weights_path():
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, "RealESRGAN_x2.pth")
    if not os.path.exists(path):
        print(f"esrgan: downloading weights to {path}", file=sys.stderr)
        urllib.request.urlretrieve(WEIGHTS_URL, path + ".part")
        os.replace(path + ".part", path)
    got = sha256(path)
    if got != WEIGHTS_SHA256:
        sys.exit(f"esrgan: weights hash mismatch ({got}); refusing to load {path}")
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--size", help="업스케일 뒤 이 크기(WxH)로 줄인다. 예: 1280x1920")
    ap.add_argument("--tile", type=int, default=256)
    a = ap.parse_args()

    sd = torch.load(weights_path(), map_location="cpu", weights_only=True)
    sd = sd.get("params_ema", sd.get("params", sd))
    model = RRDBNetX2()
    model.load_state_dict(sd, strict=True)
    model.eval()
    torch.set_num_threads(os.cpu_count() or 4)

    img = np.asarray(Image.open(a.src).convert("RGB")).astype(np.float32) / 255
    x = torch.from_numpy(img).permute(2, 0, 1)[None]
    H, W = x.shape[2:]
    T, P = a.tile, 16  # 타일 경계 이음새를 막으려고 16px 겹쳐서 돌린다
    out = torch.zeros(1, 3, H * 2, W * 2)
    with torch.no_grad():
        for y in range(0, H, T):
            for xx in range(0, W, T):
                y0, x0 = max(y - P, 0), max(xx - P, 0)
                y1, x1 = min(y + T + P, H), min(xx + T + P, W)
                o = model(x[:, :, y0:y1, x0:x1])
                ty, tx = y - y0, xx - x0
                h, w = min(T, H - y), min(T, W - xx)
                out[:, :, y * 2:(y + h) * 2, xx * 2:(xx + w) * 2] = o[:, :, ty * 2:(ty + h) * 2, tx * 2:(tx + w) * 2]

    res = Image.fromarray((out[0].clamp(0, 1).permute(1, 2, 0).numpy() * 255).round().astype(np.uint8))
    if a.size:
        w, h = (int(v) for v in a.size.lower().split("x"))
        res = res.resize((w, h), Image.LANCZOS)
    res.save(a.dst)
    print(f"esrgan: {a.src} {W}x{H} -> {a.dst} {res.width}x{res.height}")


if __name__ == "__main__":
    main()
