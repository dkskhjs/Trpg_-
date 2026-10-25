"""메인 테마와 시간대별 변주를 합성해 godot/audio/mus_*.ogg로 굽는다.

주제 선율은 make_audio.py의 MELODY(이 게임을 위해 작곡한 행진곡)이고,
여기에 브리지를 더해 길게 만든 뒤 악기 편성·조성·빠르기를 바꿔 여러 곡으로 편곡한다.

    python3 tools/make_music.py
"""
import os
import sys

import numpy as np

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
TRIAD = {1: (1, 3, 5), 2: (2, 4, 6), 4: (4, 6, 8), 5: (5, 7, 9), 6: (6, 8, 10)}


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
    """아침 — 메인 테마. 풀 밴드 행진곡."""
    s = Score(112)
    # 서주: 팀파니와 금관 화음
    s.drums(4, "timp", 1.2)
    s.pad("horns", [1, 1, 5, 5], horn, -1, 0.5)
    s.melody("tpt", [(5, 1), (5, 1), (8, 2), (7, 1), (6, 1), (5, 2)], trumpet, 0, 0.8)
    s.advance(4)
    # A: 트럼펫 선율
    s.melody("tpt", A_PART, trumpet)
    s.oompah("bass", A_CHORDS)
    s.offbeats("horns", A_CHORDS, horn)
    s.drums(8)
    s.advance(8)
    # A': 플루트가 옥타브 위로, 클라리넷 대선율
    s.melody("tpt", A_PART, trumpet, 0, 0.8)
    s.melody("fl", A_PART, flute, 1, 0.5)
    s.harmony("cl", A_PART, clarinet, 0, 0.45)
    s.oompah("bass", A_CHORDS)
    s.offbeats("horns", A_CHORDS, horn)
    s.drums(8)
    s.advance(8)
    # B: 현악과 합창
    s.melody("str", B_PART, strings, 0, 1.6)
    s.pad("choir", B_CHORDS, choir, -1)
    s.oompah("bass", B_CHORDS, gain=0.7)
    s.drums(8, "timp")
    s.advance(8)
    # 브리지: 호른과 클라리넷
    s.melody("horns", BRIDGE, horn, 0, 1.1)
    s.harmony("cl", BRIDGE, clarinet, 0, 0.4)
    s.pad("str", BRIDGE_CHORDS, strings, -1, 0.9)
    s.oompah("bass", BRIDGE_CHORDS, gain=0.8)
    s.drums(8, "light")
    s.advance(8)
    # A'': 전원 합주 + 글로켄슈필
    s.melody("tpt", A_PART, trumpet)
    s.melody("fl", A_PART, flute, 1, 0.5)
    s.melody("glock", [n for n in A_PART], glock, 1, 0.35)
    s.melody("str", A_PART, strings, -1, 1.2)
    s.pad("choir", A_CHORDS, choir, -1)
    s.oompah("bass", A_CHORDS)
    s.offbeats("horns", A_CHORDS, horn)
    s.drums(8)
    s.advance(8)
    # 코다
    s.melody("tpt", [(8, 2), (5, 1), (3, 1), (1, 4)], trumpet)
    s.pad("horns", [1, 1, 1, 1], horn, -1, 0.6)
    s.pad("str", [1, 1, 1, 1], strings, -1, 0.9)
    s.drums(4, "timp", 1.2)
    s.advance(4)
    return s.mix({"tpt": 0.55, "fl": 0.5, "cl": 0.5, "horns": 0.55, "bass": 0.55, "drums": 0.45,
                  "str": 0.7, "choir": 0.9, "glock": 0.6})


def mus_day():
    """낮 — 협동농장. 아코디언과 클라리넷, 가벼운 북."""
    s = Score(100)
    for part, chords, lead in [(A_PART, A_CHORDS, accordion), (B_PART, B_CHORDS, clarinet),
                               (A_PART, A_CHORDS, accordion), (BRIDGE, BRIDGE_CHORDS, flute)]:
        s.melody("lead", part, lead, 0 if lead is not flute else 1, 0.9)
        if lead is accordion:
            s.harmony("cl", part, clarinet, 0, 0.35)
        s.oompah("bass", chords, gain=0.6)
        s.offbeats("acc", chords, accordion, -1, 0.35)
        s.drums(8, "light")
        if part is A_PART:
            s.melody("glock", part[::2], glock, 2, 0.15)
        s.advance(8)
    return s.mix({"lead": 0.6, "cl": 0.5, "bass": 0.5, "acc": 0.45, "drums": 0.6, "glock": 0.5}, 1.2, 0.22)


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
