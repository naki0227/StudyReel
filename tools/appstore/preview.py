"""App Store のプレビュー動画を仕上げる。
preview.yml が録った素材（raw-ja.mp4 / raw-en.mp4）から、計画（JSON）に書いた場面だけを切り出して早回しにし、
フェードでつないで BGM を重ね、6.9 インチ用の 886×1920・30fps・30 秒以内の mp4 にする。
Apple のプレビューは画面の録画そのものしか入れられないので、字幕や写真は入れない。

  python3 tools/appstore/preview.py tools/appstore/previews/ja.json raw-ja.mp4 appstore/previews/ja-iphone67.mp4

計画の書き方（秒は素材の時刻）:
  {"music": "StudyTimerAndVideo/Resources/BGM/Morning.m4a", "fade": 0.4,
   "segments": [{"start": 59, "duration": 3.5, "speed": 2.6}, ...]}
duration は仕上がりでの長さ。speed 倍で早回しにするので、素材からは duration×speed 秒を使う。
"""
import json
import os
import subprocess
import sys
import tempfile

WIDTH, HEIGHT, FPS, LIMIT = 886, 1920, 30, 30.0


def run(args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args], check=True)


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    plan_path, src, out = sys.argv[1:]
    plan = json.load(open(plan_path))
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    music = os.path.join(root, plan.get("music", "StudyTimerAndVideo/Resources/BGM/Morning.m4a"))
    fade = float(plan.get("fade", 0.4))
    segments = plan["segments"]
    total = sum(s["duration"] for s in segments) - fade * (len(segments) - 1)
    if total > LIMIT:
        sys.exit(f"::error::{total:.1f} 秒になります。プレビューは {LIMIT:.0f} 秒まで")

    with tempfile.TemporaryDirectory() as tmp:
        parts = []
        for i, s in enumerate(segments):
            speed = float(s.get("speed", 1))
            part = os.path.join(tmp, f"part{i:02d}.mp4")
            # 素材を duration×speed 秒だけ取り、speed 倍の早回しにして 886×1920 に合わせる（幅に合わせて上下を少し切る）
            run(["-ss", str(s["start"]), "-t", str(s["duration"] * speed), "-i", src,
                 "-vf", f"setpts=(PTS-STARTPTS)/{speed},fps={FPS},scale={WIDTH}:-2:flags=lanczos,"
                        f"crop={WIDTH}:{HEIGHT}:0:(ih-{HEIGHT})/2,format=yuv420p",
                 "-t", str(s["duration"]), "-an", "-c:v", "libx264", "-crf", "16", "-preset", "medium", part])
            parts.append((part, float(s["duration"])))

        inputs = sum([["-i", p] for p, _ in parts], [])
        filters, last, offset = [], "[0:v]", 0.0
        for i in range(1, len(parts)):
            offset += parts[i - 1][1] - fade
            filters.append(f"{last}[{i}:v]xfade=transition=fade:duration={fade}:offset={offset:.3f}[x{i}]")
            last = f"[x{i}]"
        audio = (f"[{len(parts)}:a]atrim=0:{total:.3f},afade=t=in:d=0.6,afade=t=out:st={total - 1.8:.3f}:d=1.8,"
                 "aformat=sample_rates=44100:channel_layouts=stereo[a]")
        run([*inputs, "-stream_loop", "-1", "-i", music,
             "-filter_complex", ";".join(filters + [audio]),
             "-map", last, "-map", "[a]",
             "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS),
             "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", "-t", f"{total:.3f}", out])
    print(f"{out}: {total:.1f} 秒、{len(segments)} 場面")


if __name__ == "__main__":
    main()
