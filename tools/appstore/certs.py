"""署名用の証明書を整理する。
CI（GitHub Actions の TestFlight）は毎回まっさらな Mac で動くので、Xcode が自動署名のたびに
新しい Development 証明書をチームに作る。溜まると「maximum number of certificates」で署名できなくなる。
このスクリプトは、証明書の有効期限（作ってから1年）と TestFlight の実行時刻が合うものを「CI が作った証明書」とみなして消す。
その証明書の秘密鍵は使い捨ての Mac にしかなく、もう誰も使えない。

使い方（ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8 が環境変数にあること）:
  python3 tools/appstore/certs.py list
  python3 tools/appstore/certs.py match --runs runs.json [--window 30]        # 消す候補を出すだけ
  python3 tools/appstore/certs.py revoke --runs runs.json [--window 30]       # 候補を消す
  python3 tools/appstore/certs.py revoke --started 2026-10-20T06:14:47Z      # その時刻に作ったものだけ消す
runs.json は gh run list --json startedAt,conclusion の出力
"""
import argparse
import base64
import json
import os
import sys
import time
from datetime import datetime, timedelta, timezone

import jwt
import requests

BASE = "https://api.appstoreconnect.apple.com"
VALID_DAYS = 365   # Apple Development 証明書は作ってから1年
DEV_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT", "MAC_APP_DEVELOPMENT"}


def token():
    raw = os.environ["ASC_KEY_P8"]
    if "BEGIN PRIVATE KEY" not in raw:
        raw = base64.b64decode(raw).decode()
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      raw, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def api(method, path, params=None):
    res = requests.request(method, BASE + path, params=params, headers={"Authorization": f"Bearer {token()}"}, timeout=60)
    if res.status_code >= 400:
        sys.exit(f"::error::{method} {path} -> {res.status_code}\n{res.text}")
    return res.json() if res.content else {}


def certificates():
    items, url = [], "/v1/certificates?limit=200"
    while url:
        res = api("GET", url)
        items += res["data"]
        nxt = (res.get("links") or {}).get("next")
        url = nxt.replace(BASE, "") if nxt else None
    return items


def parse(ts):
    return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(timezone.utc)


def describe(c):
    a = c["attributes"]
    return f"{c['id']}  {a.get('certificateType'):<18} 期限 {a.get('expirationDate')}  {a.get('displayName') or a.get('name')}"


def matches(certs, starts, window):
    """TestFlight の開始時刻 + 1年 と期限が window 分以内に合う Development 証明書"""
    out = []
    for c in certs:
        a = c["attributes"]
        if a.get("certificateType") not in DEV_TYPES or not a.get("expirationDate"):
            continue
        exp = parse(a["expirationDate"])
        for s in starts:
            if abs((exp - (s + timedelta(days=VALID_DAYS))).total_seconds()) <= window * 60:
                out.append((c, s))
                break
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("command", choices=["list", "match", "revoke"])
    p.add_argument("--runs", help="gh run list --json startedAt,conclusion の JSON")
    p.add_argument("--started", help="この時刻（ISO）に始まった実行が作った証明書だけ")
    p.add_argument("--window", type=int, default=30, help="許す時刻のずれ（分）")
    args = p.parse_args()

    certs = certificates()
    print(f"証明書 {len(certs)} 件")
    if args.command == "list":
        for c in sorted(certs, key=lambda c: c["attributes"].get("expirationDate") or ""):
            print("  " + describe(c))
        return

    starts = []
    if args.runs:
        for run in json.load(open(args.runs)):
            if run.get("startedAt"):
                starts.append(parse(run["startedAt"]))
    if args.started:
        starts.append(parse(args.started))
    if not starts:
        sys.exit("::error::--runs か --started で、TestFlight の実行時刻を渡してください")

    found = matches(certs, starts, args.window)
    print(f"CI が作ったとみられる Development 証明書 {len(found)} 件")
    for c, s in found:
        print(f"  {describe(c)}  ← 実行 {s.isoformat()}")
    if args.command == "revoke":
        for c, _ in found:
            api("DELETE", f"/v1/certificates/{c['id']}")
            print(f"  消しました: {c['id']}")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write(f"### 証明書 {len(certs)} 件、CI が作ったもの {len(found)} 件" + ("（消しました）" if args.command == "revoke" else "") + "\n")
            for c, s in found:
                f.write(f"- `{describe(c)}` ← {s.isoformat()}\n")


if __name__ == "__main__":
    main()
