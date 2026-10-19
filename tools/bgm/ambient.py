"""Ambient study sounds (rain, brown noise). Synthesized from noise only, like the songs."""
import numpy as np
from synth import SR, write

LOOP = 60.0      # seconds
OVERLAP = 3.0    # crossfade the tail into the head so the loop has no seam


def spectral_filter(x, gain_fn):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(spec * gain_fn(np.maximum(freqs, 1.0)), len(x))


def make_loop(stereo):
    loop_n, fade_n = int(LOOP * SR), int(OVERLAP * SR)
    t = np.linspace(0, np.pi / 2, fade_n)
    head = stereo[:, :fade_n] * np.sin(t) + stereo[:, loop_n:loop_n + fade_n] * np.cos(t)
    out = stereo[:, :loop_n].copy()
    out[:, :fade_n] = head
    return out


def normalize(stereo, peak=0.7):
    return stereo / np.max(np.abs(stereo)) * peak


def rain():
    rng = np.random.default_rng(21)
    n = int((LOOP + OVERLAP) * SR)
    channels = []
    for side in range(2):
        # steady downpour: soft pink-ish wash that slowly swells
        wash = spectral_filter(rng.normal(0, 1, n), lambda f: (1 / np.sqrt(f)) * (1 / (1 + (f / 5200) ** 2)) * (f > 120))
        swell = 0.85 + 0.15 * np.sin(2 * np.pi * np.arange(n) / SR / 17 + side)
        channels.append(wash / np.std(wash) * 0.25 * swell)
    stereo = np.array(channels)

    # individual drops on the window and roof
    drop_len = int(0.03 * SR)
    t = np.arange(drop_len) / SR
    for _ in range(int(LOOP * 55)):
        start = rng.integers(0, n - drop_len)
        tone = rng.uniform(1800, 5200)
        body = np.sin(2 * np.pi * tone * t * (1 - 3 * t)) * np.exp(-t * rng.uniform(120, 260))
        click = rng.normal(0, 1, drop_len) * np.exp(-t * 900)
        drop = (0.5 * body + click) * rng.uniform(0.04, 0.22)
        pan = rng.uniform(0.15, 0.85)
        stereo[0, start:start + drop_len] += drop * (1 - pan)
        stereo[1, start:start + drop_len] += drop * pan

    # far-off rumble keeps it from sounding thin
    rumble = spectral_filter(rng.normal(0, 1, n), lambda f: 1 / (1 + (f / 180) ** 4))
    stereo += rumble / np.std(rumble) * 0.08
    return normalize(make_loop(stereo), 0.6)


def brown_noise():
    rng = np.random.default_rng(5)
    n = int((LOOP + OVERLAP) * SR)
    channels = []
    for _ in range(2):
        x = spectral_filter(rng.normal(0, 1, n), lambda f: (1 / f) * (f > 25) * (1 / (1 + (f / 2500) ** 2)))
        channels.append(x / np.std(x))
    return normalize(make_loop(np.array(channels)), 0.55)


if __name__ == '__main__':
    write('Rain', rain())
    write('BrownNoise', brown_noise())
