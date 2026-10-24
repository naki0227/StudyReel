#!/usr/bin/env python3
"""Pro にお金を払う価値があるかを確かめるための数字を、App Store Connect の売上レポートから集める（docs/pro-value.md）

  python3 tools/appstore/report.py appstore/release.yml [日数]

- ダウンロード（初めて入れた数）、無料お試しを始めた数、お試しから有料になった数、最初から有料で始めた数、解約、
  いま有料・お試し中の人数を、週ごとに出す
- 売上レポートは1〜2日遅れて出るので、きのう以前の日を読む
- 環境変数：ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8（asc.py と同じ）、ASC_VENDOR_NUMBER（App Store Connect →
  支払いと財務レポートの左上の番号）。SLACK_WEBHOOK_URL があれば、同じ内容を Slack にも送る
"""
import csv
import datetime
import gzip
import io
import os
import sys

import requests
import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc import BASE, api, token  # noqa: E402

# アプリ本体の「初めてのダウンロード」の種類（再ダウンロードとアップデートは数えない）
DOWNLOAD_TYPES = {"1", "1F", "1T", "F1"}


# 一度も購読がないアカウントでは、サブスクのレポートが「ベンダー番号が違う」（400）で断られる。1回だけ知らせて、あとは読まない
skipped = set()


def fetch(report_type, version, date, vendor):
    if report_type in skipped:
        return []
    params = {
        "filter[frequency]": "DAILY", "filter[reportDate]": date, "filter[reportSubType]": "SUMMARY",
        "filter[reportType]": report_type, "filter[vendorNumber]": vendor, "filter[version]": version,
    }
    for _ in range(3):
        try:
            res = requests.get(f"{BASE}/v1/salesReports", params=params, timeout=60,
                               headers={"Authorization": f"Bearer {token()}", "Accept": "application/a-gzip"})
            break
        except (requests.exceptions.Timeout, requests.exceptions.ConnectionError):
            continue
    else:
        print(f"::warning::{report_type} {date}: 応答がありませんでした")
        return []
    # その日の分がまだない・取引がなかった日は 404
    if res.status_code == 404:
        return []
    if res.status_code == 400 and report_type.startswith("SUBSCRIPTION") and "vendor number" in res.text.lower():
        print(f"::notice::{report_type} のレポートはまだありません（購読が1件もないと作られません）")
        skipped.add(report_type)
        return []
    if res.status_code >= 400:
        print(f"::warning::{report_type} {date} -> {res.status_code}: {res.text[:300]}")
        return []
    text = gzip.decompress(res.content).decode("utf-8")
    return list(csv.DictReader(io.StringIO(text), delimiter="\t"))


def number(row, *keys):
    for key in keys:
        value = (row.get(key) or "").strip()
        if value:
            try:
                return int(float(value))
            except ValueError:
                return 0
    return 0


def main():
    cfg = yaml.safe_load(open(sys.argv[1]))
    days = int(sys.argv[2]) if len(sys.argv) > 2 else 28
    vendor = os.environ.get("ASC_VENDOR_NUMBER", "").strip()
    if not vendor:
        print("::notice::ASC_VENDOR_NUMBER がないので、レポートは読めません（docs/pro-value.md の手順で Secrets に入れてください）")
        return
    app = api("GET", "/v1/apps", params={"filter[bundleId]": cfg["app"]})["data"][0]
    app_id = app["id"]
    sku = app["attributes"].get("sku", "")

    end = datetime.date.today() - datetime.timedelta(days=2)
    weeks = {}
    latest_active = None
    types = {}
    for offset in range(days):
        day = end - datetime.timedelta(days=offset)
        date = day.isoformat()
        # 週（月曜はじまり）ごとにまとめる
        week = (day - datetime.timedelta(days=day.weekday())).isoformat()
        w = weeks.setdefault(week, {"downloads": 0, "trials": 0, "converted": 0, "direct": 0, "cancels": 0, "renewals": 0})
        for row in fetch("SALES", "1_1", date, vendor):
            if row.get("Apple Identifier") != app_id:
                continue
            kind = row.get("Product Type Identifier") or "?"
            types[kind] = types.get(kind, 0) + number(row, "Units")
            if kind in DOWNLOAD_TYPES:
                w["downloads"] += number(row, "Units")
        for row in fetch("SUBSCRIPTION_EVENT", "1_3", date, vendor):
            if row.get("App Apple ID") not in (app_id, None) and row.get("Parent Identifier") not in (sku, None):
                continue
            event = (row.get("Event") or "").lower()
            quantity = number(row, "Quantity") or 1
            if "introductory" in event and event.startswith("start"):
                w["trials"] += quantity
            elif "from introductory" in event or "from free trial" in event:
                w["converted"] += quantity
            elif event == "subscribe":
                w["direct"] += quantity
            elif event.startswith("cancel"):
                w["cancels"] += quantity
            elif event.startswith("renew"):
                w["renewals"] += quantity
        if latest_active is None:
            rows = [r for r in fetch("SUBSCRIPTION", "1_3", date, vendor) if r.get("App Apple ID") in (app_id, None)]
            if rows:
                latest_active = {
                    "date": date,
                    "paid": sum(number(r, "Active Standard Price Subscriptions") for r in rows),
                    "trial": sum(number(r, "Active Free Trial Introductory Offer Subscriptions") for r in rows),
                }

    lines = [f"## StudyReel Pro（{end - datetime.timedelta(days=days - 1)} 〜 {end}）", "",
             "| 週（月曜から） | ダウンロード | お試し開始 | お試し→有料 | 最初から有料 | 解約 | 更新 |",
             "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"]
    total = {k: 0 for k in ("downloads", "trials", "converted", "direct", "cancels", "renewals")}
    for week in sorted(weeks):
        w = weeks[week]
        for k in total:
            total[k] += w[k]
        lines.append(f"| {week} | {w['downloads']} | {w['trials']} | {w['converted']} | {w['direct']} | {w['cancels']} | {w['renewals']} |")
    lines.append(f"| 合計 | {total['downloads']} | {total['trials']} | {total['converted']} | {total['direct']} | {total['cancels']} | {total['renewals']} |")
    lines.append("")
    if total["downloads"]:
        lines.append(f"- お試しを始めた割合：{total['trials'] / total['downloads']:.1%}（お試し開始 ÷ ダウンロード）")
    if total["trials"]:
        lines.append(f"- お試しから有料になった割合：{total['converted'] / total['trials']:.1%}（1週間遅れで数えるので、直近の週は低めに出る）")
    if latest_active:
        lines.append(f"- {latest_active['date']} 時点：有料 {latest_active['paid']} 人、お試し中 {latest_active['trial']} 人")
    if types:
        # 1F: 初めてのダウンロード、3F: 再ダウンロード、7F: アップデート（Apple の Product Type Identifier）
        lines.append("- 種類ごとの数（StudyReel）：" + "、".join(f"{k} {v}" for k, v in sorted(types.items())))
    lines.append("- 目安と、数字を見て何を決めるかは docs/pro-value.md")
    text = "\n".join(lines)
    print(text)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(text + "\n")
    hook = os.environ.get("SLACK_WEBHOOK_URL", "").strip()
    if hook:
        requests.post(hook, json={"text": text}, timeout=30)


if __name__ == "__main__":
    main()
