"""창백한 청수리의 모든 소리를 합성해 godot/audio/에 OGG로 굽는다.

실제 녹음은 하나도 쓰지 않는다. 행진곡은 이 게임을 위해 작곡한 것이고,
웅변·아나운서·군중 구호는 포먼트 합성으로 만든 알아들을 수 없는 '말소리'다.

    pip install numpy scipy      # ffmpeg(libvorbis) 필요
    python3 tools/make_audio.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "godot", "audio")
rng = np.random.default_rng(1997)


# ---------------------------------------------------------------- 기본 도구
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def sos(kind, freq, order=4):
    return signal.butter(order, freq, btype=kind, fs=SR, output="sos")


def filt(x, kind, freq, order=4):
    return signal.sosfilt(sos(kind, freq, order), x)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def place(buf, x, start):
    i = int(start * SR)
    if i >= len(buf):
        return
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n]


def env_ar(n, attack, release):
    e = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def reverb(x, seconds=1.6, wet=0.35, tone=3000):
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 7, n))
    ir = filt(ir, "lowpass", tone)
    ir /= np.sqrt(np.sum(ir ** 2))
    y = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - wet) + y * wet


def echoes(x, taps):
    y = x.copy()
    for delay, gain in taps:
        d = int(delay * SR)
        e = np.zeros_like(x)
        e[d:] = x[: len(x) - d] * gain
        y += filt(e, "lowpass", 2500, 2)
    return y


def loudspeaker(x, drive=3.0, distance=0.0):
    """낡은 혼 스피커 + 건물 사이 반향 + 거리감."""
    y = filt(x, "highpass", 380)
    y = filt(y, "lowpass", 3600)
    y = y + 0.6 * filt(y, "bandpass", [1300, 1900], 2)   # 혼 공진
    y = np.tanh(norm(y) * drive) * 0.8
    y = echoes(y, [(0.14, 0.45), (0.31, 0.3), (0.52, 0.18)])
    y = reverb(y, 2.2, 0.4, 2600)
    if distance:
        y = filt(y, "lowpass", 3600 - 2400 * distance, 2) * (1 - 0.5 * distance)
    return y


def loopable(x, fade=2.0):
    """끝 fade초를 앞부분에 겹쳐 끊김 없는 루프로 만든다."""
    f = int(fade * SR)
    body, tail = x[:-f].copy(), x[-f:]
    ramp = np.linspace(0, 1, f)
    body[:f] = body[:f] * ramp + tail * (1 - ramp)
    return body


def save(name, x, peak=0.9, quality=4):
    os.makedirs(OUT, exist_ok=True)
    pcm = (norm(x, peak) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        path = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp.name,
                        "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.unlink(tmp.name)
    print(f"{name}.ogg  {len(x) / SR:5.1f}s  {os.path.getsize(path) // 1024}KB")


# ---------------------------------------------------------------- 악기
def brass(freq, dur, bright=0.8, vib=0.004):
    t = t_axis(dur)
    f = freq * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3, 0, 1))
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = sum((bright ** k) / k * np.sin(k * phase) for k in range(1, 14))
    return x * env_ar(len(t), 0.025, min(0.08, dur / 3))


def tuba(freq, dur):
    return brass(freq, dur, bright=0.55, vib=0.0) * 1.2


def snare(dur=0.18, accent=1.0):
    t = t_axis(dur)
    nz = filt(rng.standard_normal(len(t)), "bandpass", [1500, 7000], 2) * np.exp(-t * 22)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 40)
    return (nz * 0.8 + tone * 0.5) * accent


def kick(dur=0.3):
    t = t_axis(dur)
    f = 45 + 70 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12)


def cymbal(dur=0.9):
    t = t_axis(dur)
    return filt(rng.standard_normal(len(t)), "highpass", 5000) * np.exp(-t * 5) * 0.5


# ---------------------------------------------------------------- 행진곡 (창작)
DEG = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11}
TONIC = 233.08  # B♭3


def pitch(d):
    """5 → 5도, 11 → 한 옥타브 위 1도(1'), -5 → 한 옥타브 아래 5도."""
    octave = 0
    while d > 7:
        d -= 7
        octave += 1
    while d < 1:
        d += 7
        octave -= 1
    return TONIC * 2 ** (octave + DEG[d] / 12)


# (음도, 박) — 2/4박자 16마디. 이 게임을 위해 새로 쓴 영웅풍 행진곡 선율.
MELODY = [
    (5, .75), (5, .25), (8, 1),        (7, .5), (6, .5), (5, 1),
    (3, .75), (4, .25), (5, .5), (6, .5), (5, 2),
    (6, .75), (6, .25), (9, 1),        (8, .5), (7, .5), (6, 1),
    (5, .5), (6, .5), (7, .5), (9, .5), (8, 2),
    (10, .75), (10, .25), (9, .5), (8, .5), (6, 1), (4, 1),
    (9, .75), (9, .25), (8, .5), (7, .5), (5, 2),
    (8, .5), (8, .5), (9, .5), (10, .5), (11, 1), (10, .5), (9, .5),
    (8, .75), (6, .25), (5, .5), (7, .5), (8, 2),
]
CHORDS = [1, 5, 1, 5, 4, 4, 5, 1, 1, 4, 5, 1, 1, 4, 5, 1]   # 마디별 화음 근음(음도)
TRIAD = {1: (1, 3, 5), 4: (4, 6, 8), 5: (5, 7, 9)}


def march(repeats=2, bpm=116):
    beat = 60 / bpm
    bar = beat * 2
    total = bar * 16 * repeats
    mel = np.zeros(int((total + 1) * SR))
    acc = np.zeros_like(mel)
    drums = np.zeros_like(mel)
    for r in range(repeats):
        t0 = r * bar * 16
        pos = t0
        for d, b in MELODY:
            n = brass(pitch(d), b * beat * 0.92)
            place(mel, n, pos)
            place(mel, 0.35 * brass(pitch(d) * 2, b * beat * 0.92, 0.6), pos)
            pos += b * beat
        for i, root in enumerate(CHORDS):
            bt = t0 + i * bar
            # 움-파: 정박에 튜바, 뒷박에 호른 화음
            place(acc, tuba(pitch(root) / 4, beat * 0.45), bt)
            place(acc, tuba(pitch(root + 4) / 4, beat * 0.45), bt + beat)
            for half in (0.5, 1.5):
                for d in TRIAD[root]:
                    place(acc, 0.22 * brass(pitch(d) / 2, beat * 0.3, 0.5), bt + half * beat)
            place(drums, kick(), bt)
            place(drums, 0.6 * kick(), bt + beat)
            place(drums, snare(accent=0.5), bt + 0.5 * beat)
            place(drums, snare(accent=0.5), bt + 1.5 * beat)
            if i % 4 == 3:  # 마디 끝 스네어 롤
                for k in range(6):
                    place(drums, snare(0.1, 0.35 + k * 0.08), bt + beat + k * beat / 6)
            if i % 8 == 0:
                place(drums, cymbal(), bt)
    x = mel * 0.55 + acc * 0.5 + drums * 0.5
    return reverb(x[: int(total * SR)], 1.2, 0.2)


# ---------------------------------------------------------------- 말소리 합성
VOWELS = {  # 한국어 모음의 대략적 포먼트 (F1, F2, F3)
    "a": (800, 1250, 2600), "eo": (600, 950, 2450), "o": (450, 800, 2450),
    "u": (330, 800, 2300), "eu": (360, 1450, 2450), "i": (290, 2250, 3000), "e": (470, 1900, 2550),
}


def resonator(x, f, bw):
    r = np.exp(-np.pi * bw / SR)
    a = [1, -2 * r * np.cos(2 * np.pi * f / SR), r * r]
    return signal.lfilter([1 - r], a, x)


def vowel(f0_curve, name, breath=0.03):
    phase = np.cumsum(f0_curve) / SR
    src = 2 * (phase % 1) - 1                       # 성대 펄스(톱니파)
    src += breath * rng.standard_normal(len(src))
    f1, f2, f3 = VOWELS[name]
    y = resonator(src, f1, 90) * 1.0 + resonator(src, f2, 120) * 0.6 + resonator(src, f3, 170) * 0.3
    return y


def consonant(dur):
    n = int(dur * SR)
    lo = rng.uniform(1500, 4000)
    return filt(rng.standard_normal(n), "bandpass", [lo, min(lo * 2.2, 15000)], 2) * env_ar(n, 0.005, dur * 0.6) * 0.25


# 웅변의 억양 윤곽. 0~1 위치 → 기준음 대비 비율. 구절마다 하나를 골라 단조로운 '음계'를 피한다.
CONTOURS = {
    "declare": lambda x: 0.30 - 0.40 * x + 0.10 * np.sin(np.pi * x * 1.5),   # 높게 시작해 가라앉는 서술조
    "exhort":  lambda x: -0.05 + 0.55 * x ** 2,                             # 고조되다 끝에서 외침
    "arch":    lambda x: 0.45 * np.sin(np.pi * x),                          # 가운데에서 정점
    "call":    lambda x: 0.15 + 0.10 * np.cos(np.pi * x * 5),               # 부르고 받는 듯한 물결
}


def oration_phrase(f0, kind, rate_range=(4.6, 6.4), vibrato=0.0):
    """억양 윤곽을 따라 음높이가 음절 사이로 미끄러지는 한 구절."""
    n_syl = int(rng.integers(4, 11))
    rate = rng.uniform(*rate_range)
    shape = CONTOURS[kind]
    targets = [f0 * (1 + shape(i / max(1, n_syl - 1)) + rng.normal(0, 0.03)) for i in range(n_syl + 1)]
    accents = rng.random(n_syl) < 0.25
    names = list(VOWELS)
    parts = []
    for i in range(n_syl):
        last = i == n_syl - 1
        dur = rng.uniform(0.6, 1.4) / rate
        if last:
            dur *= 2.4 if kind == "exhort" else rng.uniform(1.2, 1.8)
        tt = t_axis(dur)
        a, b = targets[i], targets[i + 1]
        if accents[i]:
            a *= 1.12
        if last:   # 마지막 음절: 외치거나, 툭 떨어뜨리거나
            b = a * (1.06 if kind == "exhort" else rng.uniform(0.8, 0.9))
        curve = a + (b - a) * (tt / dur) ** 1.3
        if vibrato:
            curve = curve * (1 + vibrato * np.sin(2 * np.pi * rng.uniform(5.5, 6.5) * tt))
        amp = (0.75 + 0.35 * accents[i] + (0.35 if last and kind == "exhort" else 0)) * rng.uniform(0.85, 1.0)
        v = vowel(curve, names[rng.integers(len(names))]) * env_ar(len(tt), 0.02, 0.06) * amp
        if rng.random() < 0.7:
            parts.append(consonant(rng.uniform(0.02, 0.06)))
        parts.append(v)
    return np.concatenate(parts)


def orator(seconds):
    """남성 웅변가: 구절마다 다른 억양으로, 사이사이 숨을 고르며."""
    return oration(seconds, lambda kind: oration_phrase(rng.uniform(120, 150), kind))


def announcer(seconds):
    """여성 아나운서: 높고 떨리는 격앙된 낭독조. 억양은 웅변과 같은 방식으로 구절마다 바뀐다."""
    return oration(seconds, lambda kind: oration_phrase(rng.uniform(245, 290), kind, (5.4, 7.0), 0.03))


def oration(seconds, make_phrase):
    out = []
    total = 0.0
    kinds = list(CONTOURS)
    rng.shuffle(kinds)
    i = 0
    while total < seconds:
        ph = make_phrase(kinds[i % len(kinds)])
        gap = np.zeros(int(rng.uniform(0.35, 1.0) * SR))
        out += [ph, gap]
        total += (len(ph) + len(gap)) / SR
        i += 1
    return np.concatenate(out)[: int(seconds * SR)]


def crowd_chant(syllables=("i", "u", "i", "a"), rhythm=(0.22, 0.22, 0.22, 0.6), voices=45):
    """수십 명이 한 박자로 외치는 구호(짓-부-시-자!)."""
    total = sum(rhythm) + 0.6
    out = np.zeros(int(total * SR))
    for _ in range(voices):
        f0 = rng.uniform(105, 260)
        t = rng.normal(0, 0.035)
        for syl, dur in zip(syllables, rhythm):
            d = dur * rng.uniform(0.85, 1.05)
            tt = t_axis(d)
            curve = f0 * (1.15 if dur > 0.4 else 1.0) * (1 + 0.05 * np.sin(np.pi * tt / d))
            v = vowel(curve, syl, breath=0.12) * env_ar(len(tt), 0.015, 0.06)
            place(out, consonant(0.04) * 1.5, max(0, t))
            place(out, v * rng.uniform(0.6, 1.0), max(0, t + 0.03))
            t += dur
    return out


# ---------------------------------------------------------------- 환경음
def noise(seconds, color="white"):
    n = int(seconds * SR)
    x = rng.standard_normal(n)
    if color == "brown":
        x = np.cumsum(x)
        x = filt(x, "highpass", 20, 2)
    return norm(x, 1.0)


def wind(seconds, strength=1.0):
    x = noise(seconds)
    t = t_axis(seconds)
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / 9.0) * np.sin(2 * np.pi * t / 23.0 + 1)
    lo = filt(x, "bandpass", [180, 700], 2) * (0.4 + 0.6 * lfo)
    hi = filt(x, "bandpass", [900, 2200], 2) * (lfo ** 3) * 0.25
    return (lo + hi) * strength


# ---------------------------------------------------------------- 트랙
def track_square():
    """광장: 멀리 확성기에서 아나운서 → 행진곡 → 웅변이 번갈아 흐른다."""
    m = march(2)                                  # ~33초
    a = announcer(8)
    o = orator(9)
    prog = np.concatenate([a, np.zeros(SR), m, np.zeros(SR), o, np.zeros(2 * SR)])
    prog = loudspeaker(prog, drive=3.5, distance=0.35)
    amb = wind(len(prog) / SR, 0.35)
    return loopable(prog * 0.8 + amb * 0.2)


def track_rally():
    """궐기대회: 단상의 웅변 → 군중의 구호 응답, 반복."""
    patterns = [  # 짓-부-시-자! / 만-세! / 결-사-옹-위! / 받-들-자!
        (("i", "u", "i", "a"), (0.22, 0.22, 0.22, 0.6)),
        (("a", "e"), (0.32, 0.75)),
        (("eo", "a", "o", "i"), (0.2, 0.2, 0.26, 0.62)),
        (("a", "eu", "a"), (0.24, 0.24, 0.66)),
    ]
    parts = []
    for k in range(4):
        lead = loudspeaker(orator(2.5), drive=4.5)
        syl, rhythm = patterns[k]
        reps = [crowd_chant(syl, rhythm) for _ in range(int(rng.integers(2, 4)))]
        chant = reverb(np.concatenate(reps), 1.8, 0.45)
        parts += [lead, np.zeros(int(0.3 * SR)), chant * 1.4, np.zeros(int(rng.uniform(0.5, 1.0) * SR))]
    x = np.concatenate(parts)
    murmur = filt(noise(len(x) / SR), "bandpass", [200, 1200], 2) * 0.06
    return loopable(x + murmur)


def track_radio():
    """관측소의 낡은 라디오: 30년 전 방송, 잡음, 주파수 흔들림."""
    sec = 36
    prog = np.concatenate([announcer(5), np.zeros(SR), march(1)[: int(16 * SR)] * 0.6, np.zeros(SR), announcer(5), np.zeros(10 * SR)])[: sec * SR + 2 * SR]
    prog = filt(prog, "bandpass", [320, 2600], 4)
    t = t_axis(len(prog) / SR)
    wobble = 0.65 + 0.35 * np.sin(2 * np.pi * t / 7.3) * np.sin(2 * np.pi * t / 2.9)
    hiss = filt(noise(len(prog) / SR), "highpass", 1500) * 0.18
    crackle = (rng.random(len(prog)) < 0.0015) * rng.standard_normal(len(prog)) * 2.0
    hum = 0.04 * np.sin(2 * np.pi * 50 * t)
    x = np.tanh(norm(prog) * 2.5) * wobble * 0.6 + hiss + filt(crackle, "lowpass", 4000, 2) + hum
    x = filt(x, "lowpass", 5000)
    return loopable(x)


def track_room():
    """초대소: 방 울림과, 벽 너머로 웅웅대는 확성기."""
    sec = 42
    room = filt(noise(sec + 2, "brown"), "lowpass", 300) * 0.5
    far = loudspeaker(np.concatenate([march(1), announcer(6)]), drive=3.0)[: (sec + 2) * SR]
    far = np.pad(far, (0, max(0, (sec + 2) * SR - len(far))))
    far = filt(far, "lowpass", 550, 4) * 0.35   # 벽에 막힌 소리
    return loopable(room + far)


def track_night():
    sec = 40
    x = wind(sec + 2, 0.6) + filt(noise(sec + 2, "brown"), "lowpass", 200) * 0.3
    return loopable(x)


def track_wind():
    return loopable(wind(42, 1.0))


def track_pale():
    """창백: 낮은 맥놀이 드론, 유리 같은 고음, 아주 작은 눈 내리는 소리. 소리가 '없어지는' 느낌."""
    sec = 48
    t = t_axis(sec + 2)
    drone = sum(np.sin(2 * np.pi * f * t + p) for f, p in [(55, 0), (55.4, 1), (82.4, 2), (110.3, 0.5)]) * 0.25
    glass_env = 0.5 + 0.5 * np.sin(2 * np.pi * t / 13)
    glass = (np.sin(2 * np.pi * 1760 * t) * glass_env + np.sin(2 * np.pi * 2637 * t) * (1 - glass_env)) * 0.04
    snow = filt(noise(sec + 2), "highpass", 6000) * 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 17))
    x = reverb(drone + glass + snow, 3.5, 0.6, 1800)
    return loopable(x)


# ---------------------------------------------------------------- 효과음
def sfx_dice():
    """나무 탁자 위를 구르는 주사위: 둔탁하고 낮은 '톡, 톡'."""
    out = np.zeros(int(0.8 * SR))
    hits = [(0, 1), (0.1, .75), (0.18, .8), (0.3, .5), (0.37, .45), (0.47, .3), (0.54, .22)]
    for k, (t, a) in enumerate(hits):
        n = int(0.09 * SR)
        tt = np.arange(n) / SR
        body = np.sin(2 * np.pi * (380 + 60 * (k % 3)) * tt) * np.exp(-tt * 45)       # 나무 울림
        knock = filt(rng.standard_normal(n), "bandpass", [250, 1400], 2) * np.exp(-tt * 70)
        place(out, (body * 0.7 + knock) * a, t)
    return reverb(filt(out, "lowpass", 2200), 0.5, 0.2)


def low_tone(freq, dur, attack=0.02):
    """부드럽게 부푸는 낮은 금관풍 음. 고음 배음을 깎아 알림음처럼 들리지 않게 한다."""
    t = t_axis(dur)
    x = sum(np.sin(2 * np.pi * freq * k * t) * (0.6 ** (k - 1)) for k in range(1, 6))
    x *= np.clip(t / attack, 0, 1) * np.exp(-t * 2.2)
    return filt(x, "lowpass", 1200)


def sfx_success():
    """낮은 5도 → 으뜸음으로 해결되는 화음."""
    out = np.zeros(int(2.0 * SR))
    root = TONIC / 2   # B♭2
    for f in (root * 1.5, root * 0.75):
        place(out, low_tone(f, 1.4) * 0.8, 0)
    for f in (root, root * 1.5, root * 2):
        place(out, low_tone(f, 1.7, 0.04) * 0.7, 0.16)
    place(out, kick(0.5) * 0.5, 0.16)
    return reverb(out, 1.4, 0.35, 1800)


def sfx_fail():
    """낮게 가라앉는 불협화음과 둔탁한 북소리."""
    t = t_axis(1.6)
    sink = 1 - 0.06 * t           # 음이 살짝 처진다
    x = (np.sin(2 * np.pi * 49 * sink * t) + 0.7 * np.sin(2 * np.pi * 52 * sink * t)
         + 0.35 * np.sin(2 * np.pi * 73.4 * sink * t)) * np.exp(-t * 2.2)
    x = filt(x, "lowpass", 500)
    out = np.zeros(len(t))
    place(out, kick(0.6) * 0.9, 0)
    return reverb(x + out, 1.2, 0.3, 1200)


def bell(freqs, dur=1.4):
    t = t_axis(dur)
    return sum(np.sin(2 * np.pi * f * t) * np.exp(-t * (2.5 + i)) / (i + 1) for i, f in enumerate(freqs))


def sfx_click():
    n = int(0.06 * SR)
    return filt(rng.standard_normal(n), "bandpass", [2000, 5000], 2) * np.exp(-np.linspace(0, 12, n))


def sfx_thought():
    return reverb(bell([880, 1320, 1760.5, 2641], 2.4), 2.0, 0.5)


def sfx_pale():
    """창백이 덮쳐올 때: 거꾸로 부푸는 하얀 소음."""
    t = t_axis(2.0)
    x = filt(noise(2.0), "bandpass", [2500, 9000], 2) * (t / 2.0) ** 3
    x += np.sin(2 * np.pi * 55 * t) * (t / 2.0) ** 2 * 0.4
    x *= env_ar(len(t), 0, 0.15)
    return reverb(x, 2.0, 0.5)


def sfx_name():
    """이름을 기억했을 때: 낮고 따뜻한 종소리."""
    return reverb(bell([pitch(1), pitch(1) * 2.0, pitch(1) * 3.0], 2.0), 1.2, 0.35)


def render(name, fn):
    """트랙마다 고정된 시드를 쓴다. 한 소리를 고쳐도 다른 소리는 바뀌지 않는다."""
    global rng
    rng = np.random.default_rng(sum(map(ord, name)) * 1997)
    return fn()


if __name__ == "__main__":
    for name, fn in [
        ("amb_square", track_square), ("amb_rally", track_rally), ("amb_radio", track_radio),
        ("amb_room", track_room), ("amb_night", track_night), ("amb_wind", track_wind), ("amb_pale", track_pale),
    ]:
        save(name, render(name, fn), 0.8, 3)
    for name, fn in [
        ("sfx_dice", sfx_dice), ("sfx_success", sfx_success), ("sfx_fail", sfx_fail), ("sfx_click", sfx_click),
        ("sfx_thought", sfx_thought), ("sfx_pale", sfx_pale), ("sfx_name", sfx_name),
    ]:
        save(name, render(name, fn), 0.85, 5)
