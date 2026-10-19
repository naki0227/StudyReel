"""Apply appstore/release.yml to App Store Connect through the App Store Connect API.

Usage: python3 tools/appstore/asc.py appstore/release.yml [--dry-run]

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 (the .p8 contents, raw or base64) in the environment.
With --dry-run it only reads from App Store Connect and prints what it would change.
"""
import base64
import hashlib
import os
import sys
import time

import jwt
import requests
import yaml

BASE = "https://api.appstoreconnect.apple.com"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "INVALID_BINARY"}
IN_REVIEW = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "ACCEPTED",
             "PROCESSING_FOR_DISTRIBUTION", "PENDING_APPLE_RELEASE"}

VERSION_FIELDS = {"whats_new": "whatsNew", "description": "description", "keywords": "keywords",
                  "promotional_text": "promotionalText", "support_url": "supportUrl",
                  "marketing_url": "marketingUrl"}
INFO_FIELDS = {"name": "name", "subtitle": "subtitle", "privacy_policy_url": "privacyPolicyUrl"}
REVIEW_FIELDS = {"first_name": "contactFirstName", "last_name": "contactLastName",
                 "email": "contactEmail", "phone": "contactPhone", "notes": "notes"}

DRY = "--dry-run" in sys.argv


def load_key():
    raw = os.environ["ASC_KEY_P8"]
    if "BEGIN PRIVATE KEY" not in raw:
        raw = base64.b64decode(raw).decode()
    return raw


KEY = load_key()
_token = {"value": None, "exp": 0}


def token():
    now = int(time.time())
    if _token["exp"] - now < 60:
        _token["value"] = jwt.encode(
            {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
            KEY, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})
        _token["exp"] = now + 1100
    return _token["value"]


def api(method, path, body=None, params=None, allow=()):
    if DRY and method != "GET":
        print(f"  [dry-run] {method} {path}")
        return {"data": {"id": "DRY", "attributes": {}}}
    res = requests.request(method, BASE + path, json=body, params=params,
                           headers={"Authorization": f"Bearer {token()}"}, timeout=60)
    if res.status_code in allow:
        return None
    if res.status_code >= 400:
        print(f"::error::{method} {path} -> {res.status_code}\n{res.text}")
        sys.exit(1)
    return res.json() if res.content else {}


def changed(current, wanted):
    return {k: v for k, v in wanted.items() if (current.get(k) or "") != (v or "")}


def pick(section, mapping):
    return {mapping[k]: (v.rstrip("\n") if isinstance(v, str) else v)
            for k, v in (section or {}).items() if k in mapping}


def find_app(bundle):
    data = api("GET", "/v1/apps", params={"filter[bundleId]": bundle})["data"]
    if not data:
        sys.exit(f"::error::App {bundle} が App Store Connect に見つかりません")
    print(f"App: {data[0]['attributes']['name']} ({data[0]['id']})")
    return data[0]["id"]


def state_of(version):
    attrs = version["attributes"]
    return attrs.get("appVersionState") or attrs.get("appStoreState")


def find_or_create_version(app_id, version_string):
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions",
                   params={"filter[platform]": "IOS", "limit": 50})["data"]
    for v in versions:
        if v["attributes"]["versionString"] == version_string:
            return v, versions
    for v in versions:
        if state_of(v) in EDITABLE:
            print(f"編集中のバージョン {v['attributes']['versionString']} を {version_string} に変更")
            api("PATCH", f"/v1/appStoreVersions/{v['id']}",
                {"data": {"type": "appStoreVersions", "id": v["id"], "attributes": {"versionString": version_string}}})
            v["attributes"]["versionString"] = version_string
            return v, versions
    print(f"バージョン {version_string} を作成")
    created = api("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": version_string},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
    created["attributes"].setdefault("appVersionState", "PREPARE_FOR_SUBMISSION")
    return created, versions


def update_version_attributes(version, cfg):
    wanted = {}
    if cfg.get("release"):
        wanted["releaseType"] = {"manual": "MANUAL", "after_approval": "AFTER_APPROVAL"}[cfg["release"]]
    if cfg.get("copyright"):
        wanted["copyright"] = cfg["copyright"]
    diff = changed(version["attributes"], wanted)
    if diff:
        print(f"バージョン設定: {diff}")
        api("PATCH", f"/v1/appStoreVersions/{version['id']}",
            {"data": {"type": "appStoreVersions", "id": version["id"], "attributes": diff}})


def update_localizations(version_id, cfg):
    locs = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    by_locale = {l["attributes"]["locale"]: l for l in locs}
    for locale, section in (cfg.get("localizations") or {}).items():
        loc = by_locale.get(locale)
        wanted = pick(section, VERSION_FIELDS)
        if not loc:
            print(f"::warning::{locale} のストア情報がないので飛ばします（App Store Connect で言語を追加してください）")
            continue
        diff = changed(loc["attributes"], wanted)
        if diff:
            print(f"{locale}: {', '.join(diff)} を更新")
            api("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}",
                {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": diff}})
        else:
            print(f"{locale}: 変更なし")
    return by_locale


def update_app_info(app_id, cfg):
    sections = {loc: pick(s, INFO_FIELDS) for loc, s in (cfg.get("localizations") or {}).items()}
    if not any(sections.values()):
        return
    infos = api("GET", f"/v1/apps/{app_id}/appInfos")["data"]
    info = next((i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState"))
                 not in ("READY_FOR_DISTRIBUTION", "READY_FOR_SALE")), infos[0])
    locs = api("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]
    by_locale = {l["attributes"]["locale"]: l for l in locs}
    for locale, wanted in sections.items():
        loc = by_locale.get(locale)
        if not wanted or not loc:
            continue
        diff = changed(loc["attributes"], wanted)
        if diff:
            print(f"{locale} アプリ情報: {', '.join(diff)} を更新")
            api("PATCH", f"/v1/appInfoLocalizations/{loc['id']}",
                {"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": diff}})


def find_build(app_id, cfg, wait_minutes):
    params = {"filter[app]": app_id, "filter[preReleaseVersion.version]": cfg["version"],
              "sort": "-uploadedDate", "limit": 1}
    if str(cfg.get("build", "latest")) != "latest":
        params["filter[version]"] = str(cfg["build"])
    deadline = time.time() + wait_minutes * 60
    while True:
        data = api("GET", "/v1/builds", params=params)["data"]
        if data and data[0]["attributes"]["processingState"] == "VALID":
            build = data[0]
            print(f"ビルド {build['attributes']['version']} を使用")
            return build
        state = data[0]["attributes"]["processingState"] if data else "見つからない"
        if time.time() > deadline or DRY:
            sys.exit(f"::error::ビルド {cfg.get('build')}（{cfg['version']}）が使えません: {state}")
        print(f"ビルドの処理待ち（{state}）…")
        time.sleep(60)


def attach_build(version_id, build):
    current = api("GET", f"/v1/appStoreVersions/{version_id}/relationships/build")
    if (current.get("data") or {}).get("id") == build["id"]:
        print("ビルド: 変更なし")
        return
    print("ビルドを付け替え")
    api("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": build["id"]}})


def update_review_detail(version_id, versions, cfg):
    review = cfg.get("review") or {}
    wanted = pick(review, REVIEW_FIELDS)
    if "demo_account_required" in review:
        wanted["demoAccountRequired"] = bool(review["demo_account_required"])
    res = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail", allow=(404,))
    detail = (res or {}).get("data")
    if detail:
        diff = changed(detail["attributes"], wanted)
        if diff:
            print(f"審査用の情報: {', '.join(diff)} を更新")
            api("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}",
                {"data": {"type": "appStoreReviewDetails", "id": detail["id"], "attributes": diff}})
        return
    # 連絡先が書かれていなければ、前のバージョンの連絡先を使う
    for v in versions:
        if v["id"] == version_id:
            continue
        old = (api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreReviewDetail", allow=(404,)) or {}).get("data")
        if old:
            for key in ("contactFirstName", "contactLastName", "contactEmail", "contactPhone"):
                wanted.setdefault(key, old["attributes"].get(key))
            break
    print("審査用の情報を作成")
    api("POST", "/v1/appStoreReviewDetails", {"data": {
        "type": "appStoreReviewDetails", "attributes": wanted,
        "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})


def upload_previews(by_locale, cfg, root):
    pending = []
    for locale, sets in (cfg.get("previews") or {}).items():
        loc = by_locale.get(locale)
        if not loc:
            print(f"::warning::{locale} のストア情報がないのでプレビューを飛ばします")
            continue
        existing = api("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appPreviewSets")["data"]
        for preview_type, rel_path in sets.items():
            path = os.path.join(root, rel_path)
            blob = open(path, "rb").read()
            name, size = os.path.basename(path), len(blob)
            pset = next((s for s in existing if s["attributes"]["previewType"] == preview_type), None)
            if pset:
                previews = api("GET", f"/v1/appPreviewSets/{pset['id']}/appPreviews")["data"]
                same = [p for p in previews if p["attributes"]["fileName"] == name and p["attributes"]["fileSize"] == size]
                if same:
                    print(f"{locale} {preview_type} プレビュー: 変更なし")
                    pending.append(same[0]["id"])
                    continue
                for p in previews:
                    api("DELETE", f"/v1/appPreviews/{p['id']}")
            else:
                pset = api("POST", "/v1/appPreviewSets", {"data": {
                    "type": "appPreviewSets", "attributes": {"previewType": preview_type},
                    "relationships": {"appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
            print(f"{locale} {preview_type} プレビューをアップロード（{size // 1024} KB）")
            preview = api("POST", "/v1/appPreviews", {"data": {
                "type": "appPreviews", "attributes": {"fileName": name, "fileSize": size, "mimeType": "video/mp4"},
                "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": pset["id"]}}}}})["data"]
            if DRY:
                continue
            for op in preview["attributes"]["uploadOperations"]:
                chunk = blob[op["offset"]:op["offset"] + op["length"]]
                headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
                r = requests.request(op["method"], op["url"], data=chunk, headers=headers, timeout=300)
                if r.status_code >= 400:
                    sys.exit(f"::error::プレビューのアップロードに失敗: {r.status_code} {r.text}")
            api("PATCH", f"/v1/appPreviews/{preview['id']}", {"data": {
                "type": "appPreviews", "id": preview["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
            pending.append(preview["id"])
    return pending


def wait_previews(ids, minutes=20):
    deadline = time.time() + minutes * 60
    for pid in ids:
        while True:
            attrs = api("GET", f"/v1/appPreviews/{pid}")["data"]["attributes"]
            state = (attrs.get("assetDeliveryState") or {}).get("state")
            if state == "COMPLETE":
                break
            if state == "FAILED" or time.time() > deadline:
                sys.exit(f"::error::プレビューの処理が終わりません: {state} {attrs.get('assetDeliveryState')}")
            print(f"プレビューの処理待ち（{state}）…")
            time.sleep(30)


def submit(app_id, version_id):
    subs = api("GET", "/v1/reviewSubmissions", params={
        "filter[app]": app_id, "filter[platform]": "IOS",
        "filter[state]": "READY_FOR_REVIEW,UNRESOLVED_ISSUES"})["data"]
    if subs:
        sub = subs[0]
    else:
        sub = api("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
    api("POST", "/v1/reviewSubmissionItems", {"data": {
        "type": "reviewSubmissionItems",
        "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                          "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}},
        allow=(409,))
    api("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {
        "type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print("審査に提出しました")


def main():
    cfg_path = next(a for a in sys.argv[1:] if not a.startswith("--"))
    cfg = yaml.safe_load(open(cfg_path))
    root = os.path.dirname(os.path.dirname(os.path.abspath(cfg_path)))
    if DRY:
        print("dry run: App Store Connect は読むだけで、何も変えません")

    app_id = find_app(cfg["app"])
    version, versions = find_or_create_version(app_id, str(cfg["version"]))
    state = state_of(version)
    print(f"バージョン {version['attributes']['versionString']}: {state}")
    if state in IN_REVIEW or state == "READY_FOR_DISTRIBUTION":
        print("このバージョンはもう審査に出ているので、何も変えません")
        return
    if version["id"] == "DRY":
        print("（dry run なので、これから作るバージョンの中身は確かめられません）")
        return

    update_version_attributes(version, cfg)
    by_locale = update_localizations(version["id"], cfg)
    update_app_info(app_id, cfg)
    build = find_build(app_id, cfg, wait_minutes=0 if DRY else 30)
    attach_build(version["id"], build)
    update_review_detail(version["id"], versions, cfg)
    previews = upload_previews(by_locale, cfg, root)

    if cfg.get("submit_for_review"):
        if DRY:
            print("submit_for_review: true なので、マージすると審査に出します")
            return
        wait_previews(previews)
        submit(app_id, version["id"])
    else:
        print("submit_for_review: false なので、審査には出していません")


if __name__ == "__main__":
    main()
