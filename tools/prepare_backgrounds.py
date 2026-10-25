"""장소 배경 원본을 게임용으로 가공한다.

원본(PNG 등)은 art_src/backgrounds/<id>.webp로 고화질 보관하고,
게임에는 블러를 먹인 버전을 godot/art/scenes/<id>.webp로 넣는다.
본문 글자 뒤에 깔리므로 형태만 어렴풋이 보이면 충분하다.

    python3 tools/prepare_backgrounds.py <원본 폴더> [--blur 6] [--only id ...]
원본 파일 이름에서 id를 뽑는다: chunsuri_background_<id>.png 또는 <id>.png
"""
import argparse
import os
import re

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_OUT = os.path.join(ROOT, "art_src", "backgrounds")
GAME_OUT = os.path.join(ROOT, "godot", "art", "scenes")
# 그림별 기본 블러. 창백이 주인공인 풍경은 형태가 보여야 해서 약하게.
BLUR = {"river_beyond": 1.5}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--blur", type=float, default=None, help="블러 강도 (기본 6, BLUR에 적힌 그림은 그 값)")
    ap.add_argument("--only", nargs="*", help="이 id들만 처리 (예: --only river_beyond --blur 2)")
    args = ap.parse_args()
    os.makedirs(SRC_OUT, exist_ok=True)
    os.makedirs(GAME_OUT, exist_ok=True)
    for name in sorted(os.listdir(args.folder)):
        m = re.match(r"(?:chunsuri_background_)?([a-z_]+)\.(png|jpe?g|webp)$", name)
        if not m:
            continue
        key = m.group(1)
        if args.only and key not in args.only:
            continue
        im = Image.open(os.path.join(args.folder, name)).convert("RGB")
        im.save(os.path.join(SRC_OUT, key + ".webp"), quality=92)
        blur = args.blur if args.blur is not None else BLUR.get(key, 6.0)
        im.filter(ImageFilter.GaussianBlur(blur)).save(os.path.join(GAME_OUT, key + ".webp"), quality=80)
        print(f"{key}: {im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    main()
