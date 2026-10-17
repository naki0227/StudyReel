import sys
sys.path.insert(0, '.')
from synth import *

def melody_line(track, bus, inst, scale, chords, bars, rhythm, octave_shift=12, vel=0.45, pan=0.15, seed=3, swing=0.0):
    r = np.random.default_rng(seed)
    prev = None
    for bar in range(bars):
        tones = chords[bar % len(chords)]
        for (beat, dur) in rhythm[bar % len(rhythm)]:
            strong = beat in (0, 2)
            pool = [t + octave_shift for t in tones] if strong else [s for s in scale]
            if prev is not None:
                pool = sorted(pool, key=lambda p: abs(p - prev))[:3]
            note = pool[r.integers(0, len(pool))]
            prev = note
            track.add(bus, inst(midi(note), dur * track.beat, vel * r.uniform(0.85, 1.0)), bar * 4 + beat, pan=pan, swing=swing)

# ---------------- Morning ----------------
def morning():
    t = Track(bpm=100, bars=16)
    prog = [('C', 'maj9'), ('A', 'm7'), ('F', 'maj9'), ('G', '6')]
    chords = [chord_notes(r, q, 4) for r, q in prog]
    for bar in range(16):
        c = chords[bar % 4]
        # bright e-piano chords on 1 and the "and" of 2
        for b, d in ((0, 1.4), (1.5, 0.9), (3, 0.9)):
            for i, note in enumerate(c):
                t.add('keys', epiano(midi(note), d * t.beat, 0.22), bar * 4 + b + i * 0.01, pan=-0.2 + i * 0.1)
        root = chord_notes(prog[bar % 4][0], '', 2)[0]
        for b in (0, 2, 2.5):
            t.add('bass', bass(midi(root), 0.45 * t.beat, 0.5), bar * 4 + b)
        for b in (0, 2):
            t.add('drums', kick(0.55), bar * 4 + b)
        for b in (1, 3):
            t.add('drums', snare(0.28, soft=True), bar * 4 + b)
        for e in range(8):
            t.add('perc', shaker(0.10 if e % 2 else 0.06), bar * 4 + e * 0.5, pan=0.35)
    scale = [n(x, 5) for x in ('C', 'D', 'E', 'G', 'A')] + [n('C', 6), n('D', 6)]
    rhythm = [[(0, 0.5), (0.5, 0.5), (1, 1), (2.5, 0.5), (3, 1)], [(0, 1.5), (2, 0.5), (2.5, 0.5), (3, 1)]]
    melody_line(t, 'lead', pluck, scale, chords, 16, rhythm, vel=0.28, pan=0.25, seed=11)
    kicks = [bar * 4 + b for bar in range(16) for b in (0, 2)]
    return t.mix({'keys': 1.0, 'bass': 0.8, 'drums': 0.8, 'perc': 0.9, 'lead': 0.9},
                 {'keys': 0.35, 'lead': 0.4, 'perc': 0.1},
                 duck={'targets': {'keys', 'bass'}, 'env': duck_env(t, kicks, 0.2)}, saturation=1.1)

# ---------------- Coffee Time ----------------
def coffee():
    t = Track(bpm=88, bars=16)
    prog = [('D', 'm9'), ('G', '13'), ('C', 'maj9'), ('A', '7'), ('D', 'm9'), ('G', '13'), ('E', 'm7'), ('A', '7')]
    chords = [chord_notes(r, q, 3 if r in ('G', 'A') else 4) for r, q in prog]
    swing = 0.33
    for bar in range(16):
        c = chords[bar % 8]
        for b, d in ((0, 1.6), (2.5, 1.2)):
            for i, note in enumerate(c):
                t.add('keys', epiano(midi(note), d * t.beat, 0.2), bar * 4 + b + i * 0.012, pan=-0.15 + i * 0.08, swing=swing)
        root = chord_notes(prog[bar % 8][0], '', 2)[0]
        walk = [root, root + 7, root + 12 - 2, root + 4]
        for b in range(4):
            t.add('bass', bass(midi(walk[b]), 0.8 * t.beat, 0.48), bar * 4 + b)
        for b in (0, 2.5):
            t.add('drums', kick(0.45), bar * 4 + b)
        for b in (1, 3):
            t.add('drums', snare(0.2, soft=True), bar * 4 + b)
        for e in range(8):
            t.add('perc', hat(0.12 if e % 2 else 0.18), bar * 4 + e * 0.5, pan=0.3, swing=swing)
    scale = [n(x, 5) for x in ('D', 'E', 'F', 'G', 'A', 'C')] + [n('D', 6)]
    rhythm = [[(0, 0.5), (0.5, 0.5), (1.5, 1)], [(2, 0.5), (2.5, 0.5), (3, 1)], [(0, 2)], [(1, 0.5), (1.5, 0.5), (2, 1.5)]]
    melody_line(t, 'lead', piano, scale, chords, 16, rhythm, vel=0.3, pan=0.2, seed=5, swing=swing)
    return t.mix({'keys': 1.0, 'bass': 0.85, 'drums': 0.75, 'perc': 0.6, 'lead': 0.85},
                 {'keys': 0.3, 'lead': 0.45, 'perc': 0.08}, crackle=0.4, warmth=9000, saturation=1.2)

# ---------------- Lo-fi Study ----------------
def lofi():
    t = Track(bpm=76, bars=16)
    prog = [('F', 'maj9'), ('E', 'm7'), ('D', 'm9'), ('C', 'maj9')]
    chords = [chord_notes(r, q, 3) for r, q in prog]
    swing = 0.45
    for bar in range(16):
        c = chords[bar % 4]
        for i, note in enumerate(c):
            t.add('keys', piano(midi(note), 3.6 * t.beat, 0.22, bright=0.4), bar * 4 + i * 0.03, pan=-0.2 + i * 0.1)
        if bar % 2 == 1:
            for i, note in enumerate(c[1:]):
                t.add('keys', piano(midi(note + 12), 0.8 * t.beat, 0.12, bright=0.4), bar * 4 + 2.5 + i * 0.25, pan=0.2, swing=swing)
        t.add('pad', pad(midi(c[0] + 12), 4 * t.beat, 0.12), bar * 4)
        root = chord_notes(prog[bar % 4][0], '', 2)[0]
        for b, d in ((0, 1.4), (2.5, 1.2)):
            t.add('bass', bass(midi(root), d * t.beat, 0.55), bar * 4 + b, swing=swing)
        for b in (0, 1.75, 2.5):
            t.add('drums', kick(0.7), bar * 4 + b)
        for b in (1, 3):
            t.add('drums', snare(0.42), bar * 4 + b)
        for e in range(8):
            t.add('perc', hat(0.16 if e % 2 else 0.22), bar * 4 + e * 0.5, pan=0.25, swing=swing)
    scale = [n(x, 5) for x in ('C', 'D', 'E', 'G', 'A')]
    rhythm = [[(0, 1), (1.5, 0.5), (2, 2)], [(0.5, 0.5), (1, 1), (3, 1)], [(0, 3)], [(2, 0.5), (2.5, 0.5), (3, 1)]]
    melody_line(t, 'lead', epiano, scale, chords, 16, rhythm, octave_shift=24, vel=0.18, pan=0.1, seed=21, swing=swing)
    kicks = [bar * 4 + b for bar in range(16) for b in (0, 1.75, 2.5)]
    return t.mix({'keys': 1.0, 'pad': 0.8, 'bass': 0.9, 'drums': 0.85, 'perc': 0.55, 'lead': 0.8},
                 {'keys': 0.35, 'pad': 0.5, 'lead': 0.5, 'drums': 0.05},
                 crackle=1.0, warmth=6000, saturation=1.6,
                 duck={'targets': {'keys', 'pad', 'bass'}, 'env': duck_env(t, kicks, 0.3)})

# ---------------- Piano ----------------
def piano_solo():
    t = Track(bpm=68, bars=16)
    prog = [('C', 'add9'), ('G', ''), ('A', 'm7'), ('F', 'maj7'), ('C', 'add9'), ('E', 'm7'), ('F', 'maj7'), ('G', 'sus2')]
    for bar in range(16):
        r, q = prog[bar % 8]
        c = chord_notes(r, q, 3)
        root = c[0] - 12
        t.add('piano', piano(midi(root), 3.8 * t.beat, 0.42, bright=0.6), bar * 4, pan=-0.25)
        arp = [c[0], c[1], c[2], c[-1] + (0 if c[-1] - c[0] > 12 else 12), c[2], c[1]]
        for i, note in enumerate(arp):
            t.add('piano', piano(midi(note), 1.2 * t.beat, 0.24, bright=0.6), bar * 4 + 0.5 + i * 0.5, pan=-0.05 + 0.05 * (i % 3))
    chords = [chord_notes(r, q, 4) for r, q in prog]
    scale = [n(x, 5) for x in ('C', 'D', 'E', 'G', 'A')] + [n('C', 6)]
    rhythm = [[(0, 1.5), (1.5, 0.5), (2, 2)], [(0, 1), (1, 1), (2, 1), (3, 1)], [(0, 3), (3, 1)], [(1, 1), (2, 2)]]
    melody_line(t, 'lead', lambda f, d, v: piano(f, d, v, bright=0.8), scale, chords, 16, rhythm, octave_shift=12, vel=0.36, pan=0.15, seed=8)
    return t.mix({'piano': 1.0, 'lead': 1.0}, {'piano': 0.55, 'lead': 0.6}, warmth=10000, saturation=1.05)

if __name__ == '__main__':
    for name, fn in (('Morning', morning), ('CoffeeTime', coffee), ('LofiStudy', lofi), ('Piano', piano_solo)):
        write(name, fn())
