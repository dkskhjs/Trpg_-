"""ART.md의 표를 읽어 Gemini 이미지 API로 그림을 만들고 게임 폴더에 넣는다.

    export GEMINI_API_KEY=...
    python3 tools/gen_art.py --list              # 목록과 완성 여부
    python3 tools/gen_art.py --missing           # 없는 그림 전부
    python3 tools/gen_art.py choi monument       # 골라서 (있으면 덮어씀)
    python3 tools/gen_art.py --dry-run choi      # 보낼 프롬프트만 출력

- 표의 첫 칸이 `id`, 백틱으로 감싼 영어 문장이 프롬프트다.
- 표 바로 위 제목에 '인물'이 있으면 초상화(3:4), '장소'·'배경'이면 배경(16:9),
  '소지품'이면 아이템(1:1). 설명 칸에 '(장면 그림)'이 있으면 배경으로 취급한다.
- 1장의 첫 코드 블록(스타일 블록)을 모든 프롬프트 앞에 붙이고,
  완성된 그림 한 장을 참고 이미지로 함께 보내 화풍을 맞춘다.
"""
import argparse
import base64
import io
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART_MD = os.path.join(ROOT, "ART.md")
OUT = {
    "portrait": os.path.join(ROOT, "godot", "art", "portraits"),
    "scene": os.path.join(ROOT, "art_src", "backgrounds"),
    "item": os.path.join(ROOT, "godot", "art", "items"),
}
REFERENCE = {
    "portrait": os.path.join(ROOT, "godot", "art", "portraits", "hero.webp"),
    "scene": os.path.join(ROOT, "art_src", "backgrounds", "square.webp"),
    "item": None,
}
ASPECT = {"portrait": "3:4", "scene": "16:9", "item": "1:1"}
API = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"


def parse_art_md():
    text = open(ART_MD, encoding="utf-8").read()
    style = re.search(r"```\n(.*?)```", text, re.S).group(1).strip().replace("\n", " ")
    entries, heading = [], ""
    for line in text.splitlines():
        if line.startswith("#"):
            heading = line
            continue
        m = re.match(r"\|\s*`([a-z_]+)`\s*\|(.*)\|\s*$", line)
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        prompts = [c[1:-1] for c in cells if c.startswith("`") and c.endswith("`") and " " in c]
        if not prompts:
            continue
        desc = cells[0]
        if "(장면 그림)" in desc or "장소" in heading or "배경" in heading:
            kind = "scene"
        elif "인물" in heading:
            kind = "portrait"
        elif "소지품" in heading:
            kind = "item"
        else:
            continue
        entries.append({"id": m.group(1), "kind": kind, "desc": desc, "prompt": prompts[0]})
    return style, entries


def out_path(e):
    ext = ".webp"
    return os.path.join(OUT[e["kind"]], e["id"] + ext)


def build_request(style, e):
    framing = {
        "portrait": "Bust portrait, three-quarter view, vertical 3:4 composition.",
        "scene": "Wide establishing shot, horizontal 16:9 composition, no people in the foreground unless described.",
        "item": "A single object centered on plain cream paper, square composition.",
    }[e["kind"]]
    text = f"{style}. {framing} {e['prompt']}. Match the art style of the reference image exactly."
    parts = [{"text": text}]
    ref = REFERENCE[e["kind"]]
    if ref and os.path.exists(ref):
        buf = io.BytesIO()
        Image.open(ref).convert("RGB").save(buf, "JPEG", quality=85)
        parts.append({"inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(buf.getvalue()).decode()}})
    return {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": ASPECT[e["kind"]]}},
    }, text


def call_gemini(body, key, model):
    req = urllib.request.Request(
        API.format(model=model), data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key}, method="POST")
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.load(r)
    for cand in data.get("candidates", []):
        for part in cand.get("content", {}).get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return base64.b64decode(inline["data"])
    raise RuntimeError("응답에 이미지가 없습니다: " + json.dumps(data, ensure_ascii=False)[:500])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--missing", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    style, entries = parse_art_md()
    if args.list:
        for e in entries:
            mark = "✅" if os.path.exists(out_path(e)) else "  "
            print(f"{mark} {e['kind']:8} {e['id']:14} {e['desc']}")
        return
    todo = [e for e in entries if (args.missing and not os.path.exists(out_path(e))) or e["id"] in args.ids]
    unknown = set(args.ids) - {e["id"] for e in entries}
    if unknown:
        sys.exit("ART.md에 없는 id: " + ", ".join(sorted(unknown)))
    if not todo:
        print("만들 그림이 없습니다.")
        return
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key and not args.dry_run:
        sys.exit("GEMINI_API_KEY 환경 변수가 필요합니다.")
    model = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-2.5-flash-image")

    made_scene = False
    for e in todo:
        body, text = build_request(style, e)
        if args.dry_run:
            print(f"[{e['id']}] ({e['kind']}, {ASPECT[e['kind']]})\n{text}\n")
            continue
        print(f"{e['id']}: 생성 중…", flush=True)
        try:
            raw = call_gemini(body, key, model)
        except (urllib.error.HTTPError, RuntimeError) as err:
            detail = err.read().decode()[:400] if isinstance(err, urllib.error.HTTPError) else str(err)
            print(f"  실패: {detail}")
            continue
        os.makedirs(OUT[e["kind"]], exist_ok=True)
        Image.open(io.BytesIO(raw)).convert("RGB").save(out_path(e), quality=90)
        print(f"  → {os.path.relpath(out_path(e), ROOT)}")
        made_scene |= e["kind"] == "scene"
    if made_scene:
        # 배경은 블러를 먹여 게임 폴더에 넣는다
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "prepare_backgrounds.py"), OUT["scene"]], check=True)


if __name__ == "__main__":
    main()
