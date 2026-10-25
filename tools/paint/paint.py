"""밑그림(PNG)을 붓 자국으로 덧칠해 유화처럼 만든다.

Hertzmann(1998)의 'Painterly Rendering with Curved Brush Strokes' 방식:
큰 붓부터 작은 붓 순서로, 밑그림과 지금 캔버스의 차이가 큰 곳에만
명암의 결을 따라 휘어지는 붓질을 얹는다. 마지막에 창백(칠해지지 않은
캔버스처럼 보이는 하얀 영역)과 캔버스 결을 입힌다.

    python3 tools/paint/paint.py guide.png out.png [--pale left|top|none]
"""
import argparse

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

rng = np.random.default_rng(7)


def luminance(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def paint_layer(canvas, ref, radius, threshold=22, max_len=10, alpha=0.82):
    h, w, _ = ref.shape
    lum = luminance(ref)
    gy, gx = np.gradient(lum)
    diff = np.sqrt(((canvas.astype(float) - ref) ** 2).sum(-1))
    grid = max(1, int(radius * 0.9))
    strokes = []
    for y in range(0, h, grid):
        for x in range(0, w, grid):
            y2, x2 = min(h, y + grid), min(w, x + grid)
            cell = diff[y:y2, x:x2]
            if cell.mean() < threshold:
                continue
            iy, ix = np.unravel_index(np.argmax(cell), cell.shape)
            strokes.append((y + iy, x + ix))
    rng.shuffle(strokes)

    layer = Image.fromarray(canvas)
    draw = ImageDraw.Draw(layer, "RGBA")
    for y0, x0 in strokes:
        col = ref[y0, x0] + rng.normal(0, 7, 3)          # 물감 색이 조금씩 다르다
        col = tuple(int(c) for c in np.clip(col, 0, 255)) + (int(255 * alpha),)
        pts = [(x0, y0)]
        x, y = float(x0), float(y0)
        dx0, dy0 = 0.0, 0.0
        for _ in range(max_len):
            ix, iy = int(np.clip(x, 0, w - 1)), int(np.clip(y, 0, h - 1))
            if len(pts) > 3 and np.abs(ref[iy, ix] - np.array(col[:3])).sum() > 60:
                break
            g = np.hypot(gx[iy, ix], gy[iy, ix])
            if g < 0.5:
                if len(pts) > 1:
                    break
                ang = rng.uniform(0, np.pi)
                dx, dy = np.cos(ang), np.sin(ang)
            else:
                dx, dy = -gy[iy, ix] / g, gx[iy, ix] / g     # 명암 경계를 따라
            if dx * dx0 + dy * dy0 < 0:
                dx, dy = -dx, -dy
            dx, dy = 0.6 * dx + 0.4 * dx0, 0.6 * dy + 0.4 * dy0
            n = np.hypot(dx, dy) or 1
            dx, dy = dx / n, dy / n
            x, y = x + dx * radius, y + dy * radius
            pts.append((x, y))
            dx0, dy0 = dx, dy
        width = max(1, int(radius * rng.uniform(0.8, 1.15)))
        draw.line(pts, fill=col, width=width, joint="curve")
        r = width / 2
        for px, py in (pts[0], pts[-1]):
            draw.ellipse([px - r, py - r, px + r, py + r], fill=col)
    return np.array(layer)


def pale_mask(h, w, side):
    """가장자리에서 번져 들어오는 하얀 영역. 경계가 붓질처럼 거칠다."""
    if side == "none":
        return np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w] / max(h, w)
    base = xx if side == "left" else yy
    noise = np.array(Image.fromarray((rng.random((h // 64, w // 64)) * 255).astype(np.uint8))
                     .resize((w, h), Image.BICUBIC)) / 255.0
    fine = np.array(Image.fromarray((rng.random((h // 16, w // 16)) * 255).astype(np.uint8))
                    .resize((w, h), Image.BICUBIC)) / 255.0
    edge = 0.12 + (noise - 0.5) * 0.10 + (fine - 0.5) * 0.02
    return np.clip((edge - base) / 0.12, 0, 1) ** 0.7


def canvas_grain(h, w):
    n = rng.normal(0, 1, (h, w))
    weave = (np.sin(np.arange(w) * 1.9)[None, :] + np.sin(np.arange(h) * 1.7)[:, None]) * 0.5
    return n * 4 + weave * 3


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("guide")
    ap.add_argument("out")
    ap.add_argument("--pale", default="left", choices=["left", "top", "none"])
    args = ap.parse_args()

    src = Image.open(args.guide).convert("RGB")
    ref_full = np.array(src).astype(float)
    h, w, _ = ref_full.shape

    # 바탕: 흙빛으로 밑칠
    canvas = np.array(src.filter(ImageFilter.GaussianBlur(40))).astype(np.uint8)
    for radius in (28, 16, 9, 5, 3):
        ref = np.array(src.filter(ImageFilter.GaussianBlur(radius * 0.6))).astype(float)
        canvas = paint_layer(canvas, ref, radius, threshold=24 if radius > 5 else 18,
                             max_len=12 if radius > 5 else 6)
        print(f"붓 {radius}px 완료")

    out = canvas.astype(float)
    out += canvas_grain(h, w)[..., None]
    mask = pale_mask(h, w, args.pale)[..., None]
    pale = np.array([228, 226, 218]) + canvas_grain(h, w)[..., None] * 0.6
    out = out * (1 - mask) + pale * mask
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(args.out)
    print("저장:", args.out)


if __name__ == "__main__":
    main()
