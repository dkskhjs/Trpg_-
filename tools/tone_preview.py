"""초상화 '물감 방울' 미리보기. godot/shaders/portrait.gdshader와 같은 공식이다.

그림 전체를 흑백으로 바꾸고, SPOTS에 적은 자리(손·소품·얼굴 근처)에만
물감을 떨어뜨린 것처럼 원래 색이 돌아온다. 창백 노출이 쌓이면 방울이 줄어든다.

    python3 tools/tone_preview.py [출력.jpg]
위치를 바꾸려면 SPOTS와 godot/scripts/main.gd의 PORTRAITS를 함께 고친다.
좌표는 그림 기준 0~1 (x: 왼→오, y: 위→아래), r은 그림 너비 대비 반지름.
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "godot", "art", "portraits")

# id: [(x, y, r), ...]  최대 4개
SPOTS = {
    "hero": [(0.60, 0.42, 0.09), (0.86, 0.80, 0.09)],
    "park": [(0.94, 0.89, 0.12), (0.30, 0.50, 0.15), (0.56, 0.50, 0.08)],
    "myeongsu": [(0.08, 0.34, 0.11), (0.56, 0.46, 0.10), (0.78, 0.70, 0.08)],
    "oh": [(0.80, 0.64, 0.16), (0.52, 0.49, 0.09), (0.88, 0.28, 0.07)],
    "cat": [(0.80, 0.86, 0.17), (0.52, 0.48, 0.10)],
}
PAPER = np.array([0.93, 0.91, 0.86])
INK = np.array([0.10, 0.09, 0.08])


def hash1(x):
    return np.modf(np.sin(x * 127.1 + 311.7) * 43758.5453)[0] % 1.0


def angle_noise(a, seed):
    """각도에 대한 매끈한 잡음: 방울 가장자리를 울퉁불퉁하게."""
    v = 0.0
    for k, amp in ((3, 0.5), (7, 0.3), (13, 0.2)):
        v = v + amp * np.sin(a * k + hash1(seed + k) * 6.283)
    return v


def spot_mask(u, v, aspect, x, y, r, seed, pale):
    r = r * (1.0 - 0.7 * pale)
    dx = (u - x) * aspect
    dy = v - y
    dy = np.where(dy > 0, dy * 0.8, dy)           # 아래로 살짝 흘러내림
    d = np.sqrt(dx * dx + dy * dy) / max(r, 1e-4)
    a = np.arctan2(dy, dx)
    edge = 1.0 + 0.18 * angle_noise(a, seed)
    m = np.clip((edge - d) / 0.06, 0, 1)
    for i in range(6):                             # 주변에 튄 작은 방울
        ang = hash1(seed * 7 + i) * 6.283
        dist = r * (1.2 + 0.5 * hash1(seed * 3 + i))
        rad = r * (0.05 + 0.08 * hash1(seed * 5 + i))
        sx, sy = np.cos(ang) * dist, np.sin(ang) * dist
        dd = np.sqrt((dx - sx) ** 2 + (dy - sy) ** 2)
        m = np.maximum(m, np.clip((rad - dd) / (rad * 0.3), 0, 1))
    return m


def tone(img, spots, pale=0.0):
    a = np.asarray(img.convert("RGB")) / 255.0
    h, w, _ = a.shape
    v, u = np.mgrid[0:h, 0:w]
    u, v = u / w, v / h
    aspect = w / h
    l = a @ np.array([0.299, 0.587, 0.114])
    l = np.clip((l - 0.5) * 1.15 + 0.5, 0, 1)[..., None]
    gray = INK + (PAPER - INK) * l
    m = np.zeros((h, w))
    for i, (x, y, r) in enumerate(spots):
        m = np.maximum(m, spot_mask(u, v, aspect, x, y, r * aspect, i + 1, pale))
    m = m[..., None]
    return gray * (1 - m) + a * m


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "tone_sheet.jpg"
    W, H = 300, 402
    tiles = []
    for k, spots in SPOTS.items():
        im = Image.open(os.path.join(P, k + ".webp")).convert("RGB").resize((W, H))
        tiles.append(im)
        for pale in (0.0, 0.6):
            tiles.append(Image.fromarray((np.clip(tone(im, spots, pale), 0, 1) * 255).astype(np.uint8)))
    sheet = Image.new("RGB", (W * 3, H * len(SPOTS)), "black")
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 3) * W, (i // 3) * H))
    sheet.save(out, quality=85)
    print(out)


if __name__ == "__main__":
    main()
