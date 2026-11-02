#!/usr/bin/env python3
"""翻訳した .strings を確かめる：キーが英語と同じか、%@ %d などが同じ数・同じ順か、書き方が正しいか。

  python3 tools/l10n/check.py ko      # StudyTimerAndVideo/ko.lproj と StudyReelWidget/ko.lproj を英語と比べる
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LINE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f|%)")


def parse(path):
    out, bad = {}, []
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        s = line.strip()
        if not s or s.startswith("/*") or s.startswith("//") or s.endswith("*/"):
            continue
        m = LINE.match(s)
        if not m:
            bad.append((n, s[:80]))
            continue
        out[m.group(1)] = m.group(2)
    return out, bad


def main(lang):
    problems = 0
    for folder in ("StudyTimerAndVideo", "StudyReelWidget"):
        for name in ("Localizable.strings", "InfoPlist.strings"):
            en_path = os.path.join(ROOT, folder, "en.lproj", name)
            path = os.path.join(ROOT, folder, f"{lang}.lproj", name)
            if not os.path.exists(en_path):
                continue
            if not os.path.exists(path):
                print(f"MISSING FILE {path}")
                problems += 1
                continue
            en, _ = parse(en_path)
            tr, bad = parse(path)
            for n, s in bad:
                print(f"{path}:{n}: not a valid line: {s}")
            problems += len(bad)
            for k in en:
                if k not in tr:
                    print(f"{path}: missing key {k[:60]}")
                    problems += 1
                elif sorted(SPEC.findall(en[k])) != sorted(SPEC.findall(tr[k])):
                    print(f"{path}: placeholders differ for {k[:50]}: en={SPEC.findall(en[k])} {lang}={SPEC.findall(tr[k])}")
                    problems += 1
            for k in tr:
                if k not in en:
                    print(f"{path}: extra key {k[:60]}")
                    problems += 1
            print(f"{path}: {len(tr)}/{len(en)} keys")
    print("OK" if problems == 0 else f"{problems} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
