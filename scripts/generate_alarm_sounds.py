"""Reproduce the seven original Sound V2 recordings approved in listening review.

Chime and the legacy assets are left untouched. Requires Python 3 and macOS
afconvert; generated CAF files are committed, so building the app needs neither.
"""

import argparse
from array import array
import hashlib
import math
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import wave


RATE = 44100
PEAK = 10 ** (-9 / 20)
PARTIALS = {
    "mallet": [(1, 1, 0.38), (3.98, 0.18, 0.09), (7.01, 0.035, 0.035)],
    "wood": [(1, 1, 0.07), (1.58, 0.30, 0.035), (2.4, 0.10, 0.016)],
    "warm": [(1, 1, 0.85), (2, 0.16, 0.40), (3, 0.06, 0.18)],
    "bell": [(1, 1, 0.48), (2.76, 0.28, 0.22), (5.4, 0.07, 0.09)],
    "buzz-deep": [(1, 1.4, 6), (2, 0.55, 6), (3, 0.32, 6), (4, 0.14, 6), (5, 0.09, 6), (7, 0.04, 6)],
    "glass-short": [(1, 1, 0.18), (2.01, 0.24, 0.10), (3.96, 0.06, 0.045)],
    "pulse-ring": [(1, 1, 0.45), (3, 0.23, 0.28), (5, 0.08, 0.18)],
    "ratchet-strike": [(1, 1, 0.14), (2, 0.35, 0.11), (7.17, 0.9, 0.09), (11.33, 0.5, 0.07), (15.51, 0.22, 0.04)],
}
APPROVED_PCM_SHA256 = {
    "bell_v2": "1b4a34cbf86a7a70e23a7c311bdf6959cc35538340afee644e3cd1ac31a069a9",
    "buzz_v2": "02a3c056e10c147c42a9f9a18fd83d8ee65160ba4c51fdb5c247204316728c68",
    "glasshouse": "71f4e04f8de03565d63ee49444cdff3baf9ed4cc75863454a8ede5c20b7fafb9",
    "roll_call": "e46b07e0333220df300be43a7fa3df425232670def52b0de011c523a2a11aadf",
    "ratchet": "aeee993dde34a53962cb35d1c8789f01939b3ee0d1c967614ad2201cd6b74669",
    "daybreak": "0360d1b6a5e15b1e80f34f19ae0235e2d0ba17ba6b7c01bf5ef18045e674151a",
    "clockwork": "0dca320dc16c711238de3f3358e037fc8334395c5b20f3d20429c9798c7bbbd0",
}


def note(buffer, start, midi, duration, voice="mallet", gain=1):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    offset = round(start * RATE)
    for i in range(int(duration * RATE)):
        t = i / RATE
        attack = min(t / 0.008, 1)
        release = min((duration - t) / 0.04, 1)
        signal = sum(
            weight * math.sin(math.tau * frequency * ratio * t) * math.exp(-t / decay)
            for ratio, weight, decay in PARTIALS[voice]
            if frequency * ratio < RATE / 2
        )
        if voice == "buzz-deep":
            signal *= 0.86 + 0.14 * math.cos(math.tau * 8 * t)
        buffer[(offset + i) % len(buffer)] += gain * attack * release * signal


def tick(buffer, start, gain, seed):
    rng = random.Random(seed)
    previous = smooth = 0.0
    for i in range(int(RATE * 0.07)):
        t = i / RATE
        smooth = 0.72 * smooth + 0.28 * rng.uniform(-1, 1)
        signal = smooth - previous
        previous = smooth
        envelope = min(t / 0.003, 1) * math.exp(-t / 0.014)
        buffer[(round(start * RATE) + i) % len(buffer)] += gain * envelope * signal


def daybreak():
    data = [0.0] * (RATE * 8)
    for bar in range(4):
        base = 2 * bar
        for step, midi in [(0, 74), (0.5, 69), (1.0, 78), (1.5, 76 if bar % 2 == 0 else 81)]:
            note(data, base + step, midi, 1.25, gain=0.6)
        note(data, base, 50 if bar < 2 else 57, 2, "warm", 0.13)
    return data


def clockwork():
    data = [0.0] * (RATE * 8)
    for beat in range(32):
        start = beat * 0.25
        tick(data, start, 0.8 if beat % 4 == 0 else 0.35, beat)
        note(data, start, 62 if beat % 2 == 0 else 69, 0.18, "wood", 0.24)
    for bar in range(4):
        for step, midi in [(0, 74), (0.75, 78), (1.5, 81)]:
            note(data, bar * 2 + step, midi, 0.9, "mallet", 0.44)
    return data


def bell():
    data = [0.0] * (RATE * 8)
    for pair in range(8):
        note(data, pair, 62, 0.9, "bell", 0.62)
        note(data, pair + 0.23, 62, 0.75, "bell", 0.50)
    return data


def buzz():
    data = [0.0] * (RATE * 8)
    for start, midi, duration in [
        (0, 41, 1.35), (2, 41, 0.58), (2.76, 41, 0.58),
        (4, 41, 1.35), (6, 41, 0.55), (6.8, 40, 0.70),
    ]:
        note(data, start, midi, duration, "buzz-deep", 0.5)
    return data


def glasshouse():
    data = [0.0] * (RATE * 8)
    motifs = [[72, 76, 79, 76], [74, 77, 81, 79], [72, 76, 83, 79], [74, 77, 79, 72]]
    for bar, motif in enumerate(motifs):
        for index, (offset, midi) in enumerate(zip([0, 0.38, 0.88, 1.35], motif)):
            note(data, bar * 2 + offset, midi - 12 if index == 0 else midi, 0.42, "glass-short", 0.65)
        note(data, bar * 2, motif[0] - 12, 0.5, "mallet", 0.13)
    return data


def roll_call():
    data = [0.0] * (RATE * 8)
    rhythms = [
        [0, 0.19, 0.43, 1.02, 1.31],
        [0, 0.28, 0.49, 1.07, 1.51],
        [0, 0.16, 0.52, 0.96, 1.37],
        [0, 0.24, 0.48, 1.12, 1.60],
    ]
    for bar, offsets in enumerate(rhythms):
        for index, offset in enumerate(offsets):
            midi = 76 if index < 3 else 81
            duration = [0.13, 0.10, 0.21, 0.15, 0.24][index] + 0.28
            note(data, bar * 2 + offset, midi, duration, "pulse-ring", 0.62 if index in (0, 3) else 0.47)
    return data


def ratchet():
    data = [0.0] * (RATE * 8)
    for group in range(4):
        for index, offset in enumerate([0, 0.24, 0.48, 0.98, 1.22, 1.46]):
            accent = index in (0, 3)
            note(data, group * 2 + offset, 43 if accent else 43.35,
                 0.20, "ratchet-strike", 0.85 if accent else 0.63)
    return data


def render_pcm(samples):
    if not samples or not all(math.isfinite(sample) for sample in samples):
        raise ValueError("Invalid audio samples")
    dc = sum(samples) / len(samples)
    samples = [sample - dc for sample in samples]
    fade = round(RATE * 0.008)
    for i in range(fade):
        gain = math.sin(math.pi / 2 * i / fade) ** 2
        samples[i] *= gain
        samples[-1 - i] *= gain
    maximum = max(abs(sample) for sample in samples)
    if maximum == 0:
        raise ValueError("Silent audio")
    pcm = array("h", (round(sample * PEAK / maximum * 32767) for sample in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    return pcm.tobytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parents[1] / "AlarmedByMath")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    sounds = {"bell_v2": bell, "buzz_v2": buzz, "glasshouse": glasshouse,
              "roll_call": roll_call, "ratchet": ratchet, "daybreak": daybreak, "clockwork": clockwork}
    with tempfile.TemporaryDirectory(prefix="alarmed-sounds-") as temporary:
        for name, synthesize in sounds.items():
            pcm = render_pcm(synthesize())
            if hashlib.sha256(pcm).hexdigest() != APPROVED_PCM_SHA256[name]:
                raise ValueError(f"{name} differs from its approved listening master")
            # Fill most of the fallback's 30-second notification interval.
            notification_pcm = pcm * 3
            source = Path(temporary) / f"{name}.wav"
            with wave.open(str(source), "wb") as file:
                file.setnchannels(1)
                file.setsampwidth(2)
                file.setframerate(RATE)
                file.writeframes(notification_pcm)
            target = args.output_dir / f"{name}.caf"
            subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", str(source), str(target)], check=True)
            decoded = Path(temporary) / f"{name}-decoded.wav"
            subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", str(target), str(decoded)], check=True)
            with wave.open(str(decoded), "rb") as file:
                if file.readframes(file.getnframes()) != notification_pcm:
                    raise ValueError(f"{name}: CAF conversion changed audio samples")
            print(f"{target.name}: three exact approved phrases, 24 s, mono 44.1 kHz, 16-bit")


if __name__ == "__main__":
    main()
