"""StudyReel BGM generator. All sounds are synthesized here, so the output is original work."""
import numpy as np, subprocess, sys, os

SR = 44100
rng = np.random.default_rng(7)

def midi(n): return 440.0 * 2 ** ((n - 69) / 12)
NOTE = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
def n(name, octave): return 12 * (octave + 1) + NOTE[name]

def env_adsr(length, a=0.005, d=0.1, s=0.7, r=0.2, sustain_time=None):
    total = length
    t = np.arange(total) / SR
    e = np.zeros(total)
    a_n, d_n, r_n = int(a*SR), int(d*SR), int(r*SR)
    st = total - r_n if sustain_time is None else int(sustain_time*SR)
    st = max(st, a_n + d_n)
    e[:a_n] = np.linspace(0, 1, a_n, endpoint=False) if a_n else 1
    e[a_n:a_n+d_n] = np.linspace(1, s, d_n, endpoint=False)
    e[a_n+d_n:st] = s
    tail = total - st
    if tail > 0:
        e[st:] = s * np.exp(-np.arange(tail) / (r_n/5 + 1))
    return e

# ---------- instruments ----------
def piano(freq, dur, vel=0.8, bright=1.0):
    length = int((dur + 1.6) * SR)
    t = np.arange(length) / SR
    out = np.zeros(length)
    for k in range(1, 9):
        f = freq * k * (1 + 0.0004 * k * k)  # slight inharmonicity
        if f > 9000: break
        amp = (0.9 ** k) / k ** (1.2 - 0.4 * bright)
        decay = 2.8 / (1 + 0.6 * k) * (440 / max(freq, 110)) ** 0.3
        out += amp * np.sin(2*np.pi*f*t + rng.uniform(0, 6.28)) * np.exp(-t / decay)
    hammer = np.exp(-t * 60) * rng.normal(0, 0.02, length)
    out = (out + hammer) * np.minimum(1, t / 0.004)
    # damper after note release
    rel = int(dur * SR)
    out[rel:] *= np.exp(-np.arange(length - rel) / (0.25 * SR))
    return out * vel

def epiano(freq, dur, vel=0.7):
    length = int((dur + 1.2) * SR)
    t = np.arange(length) / SR
    idx = 2.2 * np.exp(-t * 3.5)
    mod = np.sin(2*np.pi*freq*t) * idx
    out = np.sin(2*np.pi*freq*t + mod) * np.exp(-t * 1.1)
    out += 0.25 * np.sin(2*np.pi*freq*2*t) * np.exp(-t * 3)
    out += 0.08 * np.sin(2*np.pi*freq*7*t) * np.exp(-t * 18)  # tine
    out *= np.minimum(1, t / 0.003)
    rel = int(dur * SR)
    out[rel:] *= np.exp(-np.arange(length - rel) / (0.3 * SR))
    tremolo = 1 + 0.12 * np.sin(2*np.pi*4.5*t)
    return out * tremolo * vel

def pad(freq, dur, vel=0.25):
    length = int((dur + 1.5) * SR)
    t = np.arange(length) / SR
    out = np.zeros(length)
    for det in (-0.12, 0, 0.11):
        f = freq * 2 ** (det / 12)
        for k in range(1, 6):
            out += (1 / k ** 1.6) * np.sin(2*np.pi*f*k*t + rng.uniform(0, 6.28))
    e = env_adsr(length, a=0.8, d=0.5, s=0.8, r=1.4, sustain_time=dur)
    return lowpass(out * e, 1800) * vel / 3

def bass(freq, dur, vel=0.6):
    length = int((dur + 0.3) * SR)
    t = np.arange(length) / SR
    out = np.sin(2*np.pi*freq*t) + 0.25*np.sin(2*np.pi*2*freq*t) * np.exp(-t*4)
    e = env_adsr(length, a=0.01, d=0.3, s=0.6, r=0.25, sustain_time=dur)
    return np.tanh(out * 1.2) * e * vel

def pluck(freq, dur, vel=0.5):
    length = int((dur + 0.8) * SR)
    t = np.arange(length) / SR
    idx = 3.0 * np.exp(-t * 9)
    out = np.sin(2*np.pi*freq*t + idx * np.sin(2*np.pi*freq*3*t)) * np.exp(-t * 3.2)
    out *= np.minimum(1, t / 0.002)
    return out * vel

def kick(vel=0.9):
    length = int(0.45 * SR); t = np.arange(length) / SR
    f = 45 + 90 * np.exp(-t * 28)
    phase = 2*np.pi*np.cumsum(f) / SR
    out = np.sin(phase) * np.exp(-t * 7) + 0.3*np.exp(-t*200)*rng.normal(0,1,length)*0.2
    return np.tanh(out * 1.5) * vel

def snare(vel=0.5, soft=False):
    length = int(0.3 * SR); t = np.arange(length) / SR
    noise = rng.normal(0, 1, length)
    noise = highpass(noise, 1200)
    body = np.sin(2*np.pi*190*t) * np.exp(-t * 25)
    out = noise * np.exp(-t * (18 if not soft else 10)) * (0.6 if not soft else 0.35) + body * 0.5
    return lowpass(out, 6000) * vel

def hat(vel=0.25, open_=False):
    length = int((0.25 if open_ else 0.06) * SR); t = np.arange(length) / SR
    out = highpass(rng.normal(0, 1, length), 7000) * np.exp(-t * (14 if open_ else 70))
    return out * vel

def shaker(vel=0.12):
    length = int(0.09 * SR); t = np.arange(length) / SR
    e = np.sin(np.pi * np.minimum(t / 0.09, 1)) ** 2
    return highpass(rng.normal(0, 1, length), 5000) * e * vel

# ---------- dsp ----------
def lowpass(x, cutoff):
    # windowed-sinc FIR
    taps = 255
    fc = cutoff / SR
    m = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(2 * fc * m) * np.blackman(taps)
    h /= h.sum()
    return np.convolve(x, h, mode='same')

def highpass(x, cutoff):
    return x - lowpass(x, cutoff)

def fft_convolve(x, h):
    nfft = 1 << int(np.ceil(np.log2(len(x) + len(h))))
    return np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(h, nfft), nfft)[:len(x) + len(h) - 1]

def reverb(x, seconds=2.2, damp=4500, seed=1):
    r = np.random.default_rng(seed)
    length = int(seconds * SR); t = np.arange(length) / SR
    ir = r.normal(0, 1, length) * np.exp(-t * 6.9 / seconds)
    ir = lowpass(ir, damp)
    ir[:int(0.012*SR)] = 0  # predelay
    ir /= np.sqrt(np.sum(ir ** 2))
    return fft_convolve(x, ir)[:len(x)]

class Track:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60 / bpm
        self.length = int(bars * beats_per_bar * self.beat * SR)
        self.tail = int(3.0 * SR)
        self.buses = {}

    def add(self, bus, signal, beat_pos, pan=0.0, swing=0.0):
        pos = beat_pos
        if swing and (beat_pos * 2) % 2 == 1:  # off-beat eighth
            pos += swing * self.beat / 2
        start = int(pos * self.beat * SR)
        buf = self.buses.setdefault(bus, np.zeros((2, self.length + self.tail)))
        end = min(start + len(signal), buf.shape[1])
        if start >= end: return
        seg = signal[:end - start]
        l = np.cos((pan + 1) * np.pi / 4); r = np.sin((pan + 1) * np.pi / 4)
        buf[0, start:end] += seg * l
        buf[1, start:end] += seg * r

    def mix(self, levels, reverb_sends, crackle=0.0, warmth=None, saturation=1.0, duck=None):
        total = np.zeros((2, self.length + self.tail))
        wet_in = np.zeros_like(total)
        for bus, buf in self.buses.items():
            g = levels.get(bus, 1.0)
            sig = buf * g
            if duck and bus in duck['targets']:
                sig = sig * duck['env'][None, :sig.shape[1]]
            total += sig
            wet_in += sig * reverb_sends.get(bus, 0.0)
        if wet_in.any():
            total[0] += reverb(wet_in[0], seed=1) * 0.9
            total[1] += reverb(wet_in[1], seed=2) * 0.9
        if crackle:
            n_ = total.shape[1]
            hiss = lowpass(rng.normal(0, 1, n_), 5000) * 0.004
            pops = np.zeros(n_)
            idx = rng.integers(0, n_, int(n_ / SR * 9))
            pops[idx] = rng.normal(0, 1, len(idx)) * 0.25
            pops = lowpass(pops, 3500)
            total += (hiss + pops)[None, :] * crackle
        if warmth:
            total = np.vstack([lowpass(total[0], warmth), lowpass(total[1], warmth)])
        # fold the reverb tail back to the start so the loop is seamless
        out = total[:, :self.length].copy()
        out[:, :self.tail] += total[:, self.length:self.length + self.tail]
        out = np.tanh(out * saturation) / np.tanh(saturation)
        # normalize to a calm level
        rms = np.sqrt(np.mean(out ** 2))
        out *= 10 ** (-17 / 20) / max(rms, 1e-9)
        peak = np.max(np.abs(out))
        if peak > 0.89:
            out *= 0.89 / peak
        return out

def duck_env(track, kick_beats, depth=0.35, release=0.25):
    e = np.ones(track.length + track.tail)
    for b in kick_beats:
        s = int(b * track.beat * SR)
        r = int(release * SR)
        seg = 1 - depth * np.exp(-np.arange(r) / (r / 4))
        e[s:s + r] = np.minimum(e[s:s + r], seg[:len(e[s:s + r])])
    return e

def chord_notes(root, quality, octave):
    shapes = {
        'maj7': [0, 4, 7, 11], 'm7': [0, 3, 7, 10], '7': [0, 4, 7, 10], 'm9': [0, 3, 7, 10, 14],
        'maj9': [0, 4, 7, 11, 14], '6': [0, 4, 7, 9], '13': [0, 4, 10, 14, 21], 'add9': [0, 4, 7, 14],
        'm': [0, 3, 7], '': [0, 4, 7], 'sus2': [0, 2, 7],
    }
    base = n(root, octave)
    return [base + i for i in shapes[quality]]

def write(name, stereo):
    folder = os.path.dirname(os.path.abspath(__file__))
    wav = os.path.join(folder, f'{name}.wav')
    pcm = (np.clip(stereo.T, -1, 1) * 32767).astype('<i2')
    import wave
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    m4a = os.path.join(folder, f'{name}.m4a')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'aac', '-b:a', '160k', m4a], check=True)
    os.remove(wav)
    print(name, f'{stereo.shape[1]/SR:.1f}s')
