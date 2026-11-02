# StudyReel BGM

The four background tracks in `StudyTimerAndVideo/Resources/BGM` are original
compositions generated entirely by the scripts in this folder (additive and FM
synthesis, synthesized drums, algorithmic reverb). No samples, loops, or
third-party recordings are used, so the tracks belong to the StudyReel project
and can be bundled in the app and included in videos users export and share.

| File | Tempo | Feel |
| --- | --- | --- |
| Morning.m4a | 100 BPM | bright e-piano, pluck melody, shaker |
| CoffeeTime.m4a | 88 BPM | jazzy swing, walking bass, light vinyl |
| LofiStudy.m4a | 76 BPM | dusty piano, boom-bap drums, vinyl crackle |
| Piano.m4a | 68 BPM | solo piano arpeggios |

Each track is built to loop seamlessly (the reverb tail is folded back to the
start), so the app can repeat it for any video length.

Regenerate (needs Python 3 with numpy, and ffmpeg):

```bash
cd tools/bgm
python3 songs.py
python3 ambient.py
mv *.m4a ../../StudyTimerAndVideo/Resources/BGM/
```

`ambient.py` makes the two study sounds played on the recording screen
(Rain.m4a, BrownNoise.m4a, WhiteNoise.m4a). They are shaped noise only and loop every 60 s.
