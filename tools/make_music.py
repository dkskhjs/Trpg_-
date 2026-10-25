"""메인 테마와 시간대별 변주를 합성해 godot/audio/mus_*.ogg로 굽는다.

주제 선율은 make_audio.py의 MELODY(이 게임을 위해 작곡한 행진곡)이고,
여기에 브리지를 더해 길게 만든 뒤 악기 편성·조성·빠르기를 바꿔 여러 곡으로 편곡한다.

    python3 tools/make_music.py
"""
import os
import sys

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_audio as A  # noqa: E402
from make_audio import SR, filt, place, reverb, t_axis, env_ar, loopable, save  # noqa: E402

MAJOR = {1: 0, 2: 2, 3: 4, 4: 5, 5: 7, 6: 9, 7: 11}
MINOR = {1: 0, 2: 2, 3: 3, 4: 5, 5: 7, 6: 8, 7: 10}


def pitch(d, mode=MAJOR, tonic=A.TONIC):
    octave = 0
    while d > 7:
        d -= 7
        octave += 1
    while d < 1:
        d += 7
        octave -= 1
    return tonic * 2 ** (octave + mode[d] / 12)


def rng():
    return A.rng


# ------------------------------------------------------------------ 악곡
A_PART = A.MELODY[:22]          # 1~8마디
B_PART = A.MELODY[22:]          # 9~16마디
A_CHORDS = A.CHORDS[:8]
B_CHORDS = A.CHORDS[8:]
# 브리지: 버금딸림(IV) 쪽으로 기우는 새 8마디
BRIDGE = [
    (4, 1), (6, .5), (8, .5),     (7, 1), (6, 1),
    (5, .75), (6, .25), (4, 1),   (2, 2),
    (4, .5), (5, .5), (6, .5), (8, .5), (9, 1), (8, 1),
    (7, .75), (6, .25), (5, .5), (4, .5), (5, 2),
]
BRIDGE_CHORDS = [4, 4, 1, 5, 4, 1, 5, 5]
TRIAD = {1: (1, 3, 5), 2: (2, 4, 6), 3: (3, 5, 7), 4: (4, 6, 8), 5: (5, 7, 9), 6: (6, 8, 10), 7: (7, 9, 11)}


# ------------------------------------------------------------------ 악기
def adsr(n, a, d, s, r):
    e = np.full(n, s)
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    a = min(a, n)
    e[:a] = np.linspace(0, 1, a)
    d = min(d, n - a)
    e[a:a + d] = np.linspace(1, s, d)
    if r and r < n:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def osc(freq, dur, harmonics, vib=0.0, vib_rate=5.5):
    t = t_axis(dur)
    f = freq * (1 + vib * np.sin(2 * np.pi * vib_rate * t) * np.clip(t * 2, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return sum(a * np.sin(k * ph) for k, a in harmonics)


def trumpet(f, d):
    x = osc(f, d, [(k, 0.82 ** k / k * 2) for k in range(1, 14)], vib=0.005)
    return x * adsr(len(x), 0.03, 0.1, 0.8, min(0.08, d / 3))


def horn(f, d):
    x = osc(f, d, [(k, 0.6 ** k) for k in range(1, 8)], vib=0.003)
    return filt(x, "lowpass", 1400) * adsr(len(x), 0.06, 0.15, 0.85, min(0.15, d / 3))


def clarinet(f, d):
    x = osc(f, d, [(1, 1), (3, 0.45), (5, 0.25), (7, 0.12), (9, 0.06)], vib=0.004, vib_rate=5)
    x += 0.02 * filt(rng().standard_normal(len(x)), "bandpass", [1500, 4000], 2)
    return x * adsr(len(x), 0.05, 0.1, 0.9, min(0.1, d / 3))


def flute(f, d):
    x = osc(f, d, [(1, 1), (2, 0.2), (3, 0.06)], vib=0.008, vib_rate=5.2)
    x += 0.05 * filt(rng().standard_normal(len(x)), "bandpass", [f, min(f * 4, 12000)], 2)
    return x * adsr(len(x), 0.06, 0.1, 0.85, min(0.1, d / 3))


def accordion(f, d):
    """두 리드를 살짝 어긋나게 조율한 뮤제트 음색."""
    t = t_axis(d)
    x = np.zeros(len(t))
    for detune in (1.0, 1.006):
        ph = 2 * np.pi * f * detune * t
        x += np.sign(np.sin(ph)) * 0.35 + (2 * ((f * detune * t) % 1) - 1) * 0.35
    x = filt(x, "lowpass", 2600)
    return x * adsr(len(x), 0.04, 0.05, 0.9, min(0.06, d / 4)) * 0.6


def strings(f, d):
    t = t_axis(d)
    x = np.zeros(len(t))
    for det in (-0.004, 0, 0.0035, 0.007):
        ff = f * (1 + det) * (1 + 0.004 * np.sin(2 * np.pi * (5 + det * 100) * t))
        x += 2 * ((np.cumsum(ff) / SR) % 1) - 1
    x = filt(x, "lowpass", 2800)
    return x * adsr(len(x), min(0.35, d / 3), 0.1, 0.9, min(0.4, d / 3)) * 0.25


def glock(f, d=1.2):
    t = t_axis(max(d, 1.2))
    return sum(np.sin(2 * np.pi * f * m * t) * np.exp(-t * dec) * a
               for m, dec, a in [(1, 3, 1), (2.76, 6, 0.4), (5.4, 10, 0.2)])


def music_box(f, d=2.0):
    t = t_axis(max(d, 2.0))
    return sum(np.sin(2 * np.pi * f * m * t) * np.exp(-t * dec) * a
               for m, dec, a in [(1, 1.6, 1), (3.0, 4, 0.25), (6.1, 8, 0.1)])


def choir(f, d, vowel="a"):
    out = np.zeros(int(d * SR))
    for _ in range(5):
        curve = np.full(len(out), f * rng().uniform(0.995, 1.005))
        curve *= 1 + 0.006 * np.sin(2 * np.pi * rng().uniform(4.5, 5.5) * t_axis(d))
        out += A.vowel(curve, vowel, breath=0.05)
    out = filt(out, "lowpass", 3500)
    return out * adsr(len(out), min(0.3, d / 3), 0.1, 0.9, min(0.3, d / 3)) * 0.12


def timpani(f, d=1.0):
    t = t_axis(d)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 3) + 0.3 * np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t * 5)
    x += filt(rng().standard_normal(len(t)), "lowpass", 400) * np.exp(-t * 20) * 0.5
    return x


def brush(d=0.15):
    t = t_axis(d)
    return filt(rng().standard_normal(len(t)), "bandpass", [2000, 8000], 2) * np.exp(-t * 25) * 0.25


# ---- 실제 악기에 가까운 음색 (아침·낮) ----
def pluck(f, d, bright=0.5, body=True):
    """카플러스-스트롱 뜯는 현. 짧은 소음이 지연선 안에서 걸러지며 현처럼 울린다."""
    n = int(max(d, 1.5) * SR)
    # 두 표본 평균 필터가 반 표본 지연을 더하므로 지연선 길이는 주기 − 0.5
    N = max(2, int(round(SR / f - 0.5)))
    burst = filt(rng().standard_normal(N), "lowpass", 1500 + 6000 * bright, 2)
    x = np.zeros(n)
    x[:N] = burst
    g = 0.996
    a = np.zeros(N + 2)
    a[0] = 1
    a[N] = a[N + 1] = -g * 0.5
    y = signal.lfilter([1], a, x)
    if body:
        y = y + 0.4 * filt(y, "bandpass", [180, 420], 2)
    return y * np.exp(-np.arange(n) / SR * 1.2)


def gayageum(f, d):
    """가야금풍: 어두운 뜯음 + 줄을 누른 듯 살짝 떠는 여음."""
    y = pluck(f, d, 0.35)
    t = np.arange(len(y)) / SR
    shake = 1 + 0.25 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.25) * 3, 0, 1)
    return y * shake


def piano(f, d):
    """배음이 조금씩 높게 어긋나는(비조화) 피아노 음, 해머 소리."""
    dur = max(d, 2.5)
    t = t_axis(dur)
    B = 0.0004
    x = np.zeros(len(t))
    for k in range(1, 10):
        fk = k * f * np.sqrt(1 + B * k * k)
        if fk > SR / 2.2:
            break
        decay = 1.2 + 0.6 * k
        x += np.sin(2 * np.pi * fk * t + rng().uniform(0, 6)) * np.exp(-t * decay) / k ** 1.1
    hammer = filt(rng().standard_normal(len(t)), "bandpass", [800, 3000], 2) * np.exp(-t * 80) * 0.15
    x = x + hammer
    rel = int(min(len(t), d * SR + 0.3 * SR))
    x[rel:] *= np.exp(-np.arange(len(t) - rel) / SR * 8)
    return x * 0.7


def bowed(curve, nasal=False):
    """음높이 곡선을 따라 켜는 찰현. nasal=True면 해금처럼 코맹맹이 소리."""
    ph = np.cumsum(curve) / SR
    x = 2 * (ph % 1) - 1
    x += 0.06 * rng().standard_normal(len(x))           # 활 마찰
    if nasal:
        x = filt(x, "bandpass", [500, 3200], 2) + 0.8 * filt(x, "bandpass", [1100, 1600], 2)
    else:
        x = filt(x, "lowpass", 1800) + 0.5 * filt(x, "bandpass", [200, 500], 2)
    return x


def cello(f, d):
    t = t_axis(d)
    curve = f * (1 + 0.005 * np.sin(2 * np.pi * 4.8 * t) * np.clip(t - 0.4, 0, 1))
    return bowed(curve) * adsr(len(t), min(0.8, d / 3), 0.2, 0.85, min(0.8, d / 3)) * 0.5


def glide_phrase(notes, beat, p, slide=0.07, vib=0.012):
    """음 사이를 미끄러지며 잇는 한 줄의 음높이 곡선과 음량 곡선(해금·첼로 선율용)."""
    total = sum(b for _, b in notes) * beat
    n = int(total * SR)
    curve = np.zeros(n)
    amp = np.zeros(n)
    t0 = 0
    prev = p(notes[0][0])
    for d, b in notes:
        f = p(d)
        m = int(b * beat * SR)
        tt = np.arange(m) / SR
        s = min(int(slide * SR), m)
        seg = np.full(m, f)
        seg[:s] = prev * (f / prev) ** (np.arange(s) / max(1, s))
        onset = np.clip((tt - 0.25) * 2, 0, 1)
        seg *= 1 + vib * onset * np.sin(2 * np.pi * 5.2 * tt)
        curve[t0:t0 + m] = seg[: n - t0]
        e = np.ones(m) * 0.9
        e[: int(0.05 * SR)] = np.linspace(0.45, 0.9, min(m, int(0.05 * SR)))   # 활을 다시 긋는 순간
        amp[t0:t0 + m] = e[: n - t0]
        t0 += m
        prev = f
    return curve, amp


def janggu(kind="kung"):
    t = t_axis(0.5)
    if kind == "kung":   # 북편: 낮고 둥근 소리
        return np.sin(2 * np.pi * (85 + 40 * np.exp(-t * 30)) * t) * np.exp(-t * 7)
    # 채편: 높고 마른 소리
    return filt(rng().standard_normal(len(t)), "bandpass", [900, 4000], 2) * np.exp(-t * 35) * 0.6 \
        + np.sin(2 * np.pi * 420 * t) * np.exp(-t * 30) * 0.3


def tape(x, wow=0.0016, flutter=0.00025, hiss=0.0025):
    """낡은 테이프: 느리게 늘어지고(와우) 빠르게 떨리며(플러터) 쉬쉬 소리가 낀다."""
    n = len(x)
    t = np.arange(n) / SR
    delay = 0.004 + wow * np.sin(2 * np.pi * 0.45 * t) + flutter * np.sin(2 * np.pi * 6.3 * t)
    y = np.interp(t - delay, t, x, left=0)
    y = filt(y, "lowpass", 7000, 2)
    y = np.tanh(y / (np.max(np.abs(y)) or 1) * 1.4) * 0.8
    return y + hiss * filt(rng().standard_normal(n), "highpass", 3000, 2)


def flatten(notes):
    """점음표(따-단)를 고르게 풀어 행진곡의 들뜬 느낌을 지운다."""
    out = []
    i = 0
    while i < len(notes):
        d, b = notes[i]
        if b == .75 and i + 1 < len(notes) and notes[i + 1][1] == .25:
            out += [(d, .5), (notes[i + 1][0], .5)]
            i += 2
        else:
            out.append((d, b))
            i += 1
    return out


PENTA = [1, 3, 4, 5, 7]   # 단조 오음음계(계면조풍): 1 ♭3 4 5 ♭7


# ------------------------------------------------------------------ 편곡 엔진
class Score:
    def __init__(self, bpm, mode=MAJOR, tonic=A.TONIC):
        self.beat = 60 / bpm
        self.mode = mode
        self.tonic = tonic
        self.t = 0.0
        self.tracks = {}

    def p(self, d):
        return pitch(d, self.mode, self.tonic)

    def buf(self, name):
        return self.tracks.setdefault(name, np.zeros(SR * 400))

    def melody(self, name, notes, inst, octave=0, gain=1.0, legato=0.92, skip=0.0):
        t = self.t
        for d, b in notes:
            if skip and rng().random() < skip:      # 창백: 음이 지워진다
                t += b * self.beat
                continue
            place(self.buf(name), inst(self.p(d) * 2 ** octave, b * self.beat * legato) * gain, t)
            t += b * self.beat

    def harmony(self, name, notes, inst, octave=0, gain=1.0):
        """선율 아래 3도로 따라가는 대선율."""
        self.melody(name, [(d - 2, b) for d, b in notes], inst, octave, gain)

    def oompah(self, name, chords, inst=A.tuba, gain=1.0):
        for i, root in enumerate(chords):
            bt = self.t + i * 2 * self.beat
            place(self.buf(name), inst(self.p(root) / 4, self.beat * 0.45) * gain, bt)
            place(self.buf(name), inst(self.p(root + 4) / 4, self.beat * 0.45) * gain, bt + self.beat)

    def offbeats(self, name, chords, inst, octave=-1, gain=0.3):
        for i, root in enumerate(chords):
            bt = self.t + i * 2 * self.beat
            for half in (0.5, 1.5):
                for d in TRIAD[root]:
                    place(self.buf(name), inst(self.p(d) * 2 ** octave, self.beat * 0.3) * gain, bt + half * self.beat)

    def pad(self, name, chords, inst, octave=-1, gain=1.0, bars_per_chord=1):
        for i, root in enumerate(chords):
            bt = self.t + i * 2 * self.beat
            for d in TRIAD[root]:
                place(self.buf(name), inst(self.p(d) * 2 ** octave, 2 * self.beat * bars_per_chord * 1.05) * gain, bt)

    def drums(self, bars, style="march", gain=1.0):
        for i in range(bars):
            bt = self.t + i * 2 * self.beat
            if style == "march":
                place(self.buf("drums"), A.kick() * gain, bt)
                place(self.buf("drums"), A.kick() * 0.6 * gain, bt + self.beat)
                for h in (0.5, 1.5):
                    place(self.buf("drums"), A.snare(accent=0.45) * gain, bt + h * self.beat)
                if i % 4 == 3:
                    for k in range(6):
                        place(self.buf("drums"), A.snare(0.1, 0.3 + k * 0.08) * gain, bt + self.beat + k * self.beat / 6)
                if i % 8 == 0:
                    place(self.buf("drums"), A.cymbal() * gain, bt)
            elif style == "light":
                place(self.buf("drums"), A.kick(0.2) * 0.5 * gain, bt)
                for h in (0.5, 1, 1.5):
                    place(self.buf("drums"), brush() * gain, bt + h * self.beat)
            elif style == "timp":
                if i % 2 == 0:
                    place(self.buf("drums"), timpani(self.p(1) / 4, 1.5) * 0.6 * gain, bt)

    def advance(self, bars):
        self.t += bars * 2 * self.beat

    def mix(self, levels, room=1.6, wet=0.3):
        n = int((self.t + 3) * SR)
        out = sum(self.tracks[k][:n] * levels.get(k, 1.0) for k in self.tracks)
        return reverb(out, room, wet)


# ------------------------------------------------------------------ 곡
def mus_morning():
    """아침 — 안개 낀 국경. 첼로 드론과 기타 아르페지오 위에서 피아노가 단조로 바뀐 주제를 짚고,
    멀리서 테이프로 늘어진 행진곡이 기억처럼 스친다."""
    s = Score(64, MINOR)
    melody = flatten(A_PART) + flatten(B_PART)
    chords = A_CHORDS + B_CHORDS
    for rnd in range(2):
        # 첼로: 으뜸음과 5도를 길게
        for i in range(0, 16, 2):
            bt = s.t + i * 2 * s.beat
            place(s.buf("cello"), cello(s.p(1) / 4, 4 * s.beat * 1.05), bt)
            place(s.buf("cello"), cello(s.p(5) / 4, 4 * s.beat * 1.05) * 0.6, bt)
        # 기타: 화음을 8분음표로 펼친다
        for i, root in enumerate(chords):
            bt = s.t + i * 2 * s.beat
            tones = [TRIAD[root][0], TRIAD[root][2], TRIAD[root][1] + 7, TRIAD[root][2]]
            for k, d in enumerate(tones):
                place(s.buf("gtr"), pluck(s.p(d) / 2, 1.5, 0.4) * (0.9 if k == 0 else 0.6), bt + k * 0.5 * s.beat)
        # 피아노: 주제를 띄엄띄엄 (두 번째 돌 때 더 비운다)
        s.melody("piano", melody, piano, 0, 0.9, legato=1.0, skip=0.12 if rnd == 0 else 0.3)
        if rnd == 1:
            ghost = np.zeros(int(s.beat * 2 * 16 * SR) + SR * 4)
            pos = 0.0
            for d, b in A_PART:
                place(ghost, A.brass(pitch(d, MINOR), b * s.beat * 0.9, 0.6), pos)
                pos += b * s.beat
            ghost = tape(A.loudspeaker(ghost, drive=2.5, distance=0.8), wow=0.004, hiss=0.0)
            place(s.buf("ghost"), ghost, s.t)
        s.advance(16)
    x = s.mix({"cello": 0.5, "gtr": 0.45, "piano": 0.6, "ghost": 0.25}, 2.4, 0.35)
    return tape(x)


def mus_day():
    """낮 — 협동농장의 오후. 해금이 주제를 미끄러지듯 켜고, 가야금이 오음음계로 음형을 뜯고,
    장구가 드문드문 친다."""
    s = Score(72, MINOR)
    for part, chords in [(A_PART, A_CHORDS), (B_PART, B_CHORDS), (A_PART, A_CHORDS)]:
        notes = flatten(part)
        curve, amp = glide_phrase(notes, s.beat, s.p)
        line = bowed(curve, nasal=True) * amp * 0.5
        line *= adsr(len(line), 0.3, 0.1, 1.0, 0.8)
        place(s.buf("haegeum"), line, s.t)
        # 가야금: 마디마다 오음음계 음형
        for i, root in enumerate(chords):
            bt = s.t + i * 2 * s.beat
            figure = [root, root + 4, root + 7, root + 4] if i % 2 == 0 else [root + 7, root + 6, root + 4, root]
            for k, d in enumerate(figure):
                d = min(PENTA, key=lambda q: abs(q - ((d - 1) % 7 + 1))) + 7 * ((d - 1) // 7)
                place(s.buf("gayageum"), gayageum(s.p(d) / 2, 1.2) * 0.7, bt + k * 0.5 * s.beat)
            # 장구: 덩(북편+채편) … 쿵 … 덕
            place(s.buf("janggu"), janggu("kung") + janggu("deok") * 0.6, bt)
            if i % 2 == 1:
                place(s.buf("janggu"), janggu("kung") * 0.6, bt + 1.0 * s.beat)
            place(s.buf("janggu"), janggu("deok") * 0.5, bt + 1.5 * s.beat)
        for i in range(0, 8, 4):
            place(s.buf("cello"), cello(s.p(1) / 4, 8 * s.beat * 1.05) * 0.7, s.t + i * 2 * s.beat)
        s.advance(8)
    x = s.mix({"haegeum": 0.6, "gayageum": 0.55, "janggu": 0.4, "cello": 0.4}, 1.8, 0.28)
    return tape(x, wow=0.001, hiss=0.0015)


def mus_evening():
    """저녁 — 배급소 앞. 단조, 느린 현악 위의 클라리넷."""
    s = Score(72, MINOR)
    s.melody("cl", A_PART, clarinet, 0, 0.9)
    s.pad("str", A_CHORDS, strings, -1, 1.0)
    s.drums(8, "timp", 0.5)
    s.advance(8)
    s.melody("horn", B_PART, horn, 0, 1.0)
    s.pad("str", B_CHORDS, strings, -1, 1.0)
    s.pad("choir", B_CHORDS, choir, -1, 0.7)
    s.advance(8)
    s.melody("cl", A_PART, clarinet, 0, 0.8)
    s.melody("fl", A_PART[::2], flute, 1, 0.3)
    s.pad("str", A_CHORDS, strings, -1, 1.0)
    s.advance(8)
    return s.mix({"cl": 0.7, "horn": 0.6, "str": 0.8, "choir": 0.9, "drums": 0.4, "fl": 0.5}, 2.2, 0.38)


def mus_night():
    """밤 — 초대소. 오르골이 혼자 주제를 짚는다."""
    s = Score(58, MINOR)
    s.melody("box", A_PART, music_box, 1, 0.8, legato=1.0)
    s.pad("str", A_CHORDS, strings, -2, 0.45)
    s.advance(8)
    s.melody("box", B_PART, music_box, 1, 0.7, legato=1.0)
    s.pad("str", B_CHORDS, strings, -2, 0.45)
    s.advance(8)
    return s.mix({"box": 0.6, "str": 0.6}, 3.0, 0.5)


def mus_pale():
    """창백 — 주제가 늘어지고, 음이 군데군데 지워지고, 음정이 미끄러진다."""
    s = Score(40, MINOR, A.TONIC * 0.985)
    s.melody("choir", A_PART, lambda f, d: choir(f, d, "u"), 0, 1.6, legato=1.0, skip=0.35)
    s.melody("box", A_PART, music_box, 1, 0.4, legato=1.0, skip=0.55)
    s.pad("str", [1, 1, 5, 5, 4, 4, 5, 1], strings, -2, 0.4)
    s.advance(8)
    x = s.mix({"choir": 0.9, "box": 0.5, "str": 0.6}, 4.0, 0.65)
    t = t_axis(len(x) / SR)
    drift = 0.5 + 0.5 * np.sin(2 * np.pi * t / 23)
    return x * (0.6 + 0.4 * drift)


def mus_hope():
    """기록 — 진실의 결말. 느린 장조, 현악과 합창."""
    s = Score(66)
    s.melody("str", A_PART, strings, 0, 1.8)
    s.pad("choir", A_CHORDS, choir, -1, 0.9)
    s.oompah("bass", A_CHORDS, horn, 0.4)
    s.advance(8)
    s.melody("horn", B_PART, horn, 0, 1.0)
    s.melody("str", B_PART, strings, 1, 0.8)
    s.pad("choir", B_CHORDS, choir, -1, 0.9)
    s.melody("glock", B_PART[::2], glock, 1, 0.2)
    s.advance(8)
    return s.mix({"str": 0.7, "choir": 1.0, "horn": 0.6, "bass": 0.5, "glock": 0.5}, 2.5, 0.4)


TRACKS = [("mus_morning", mus_morning), ("mus_day", mus_day), ("mus_evening", mus_evening),
          ("mus_night", mus_night), ("mus_pale", mus_pale), ("mus_hope", mus_hope)]

if __name__ == "__main__":
    only = sys.argv[1:]
    for name, fn in TRACKS:
        if only and name not in only:
            continue
        A.rng = np.random.default_rng(sum(map(ord, name)) * 1997)
        save(name, loopable(fn(), 3.0), 0.85, 4)
