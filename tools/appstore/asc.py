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
# 承認済み（PENDING_DEVELOPER_RELEASE）のバージョンを公開する。Actions の画面から release_now を付けて動かしたときだけ
RELEASE_NOW = "--release-now" in sys.argv
# App 内イベントだけを作る・直す（バージョンには触らない）
EVENTS_ONLY = "--events-only" in sys.argv


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
    url = path if path.startswith("http") else BASE + path
    # 読むだけの GET は、Apple の応答が遅いときに2回までやり直す（書き込みは二重にならないようにやり直さない）
    for attempt in range(3 if method == "GET" else 1):
        try:
            res = requests.request(method, url, json=body, params=params,
                                   headers={"Authorization": f"Bearer {token()}"}, timeout=60)
            break
        except (requests.exceptions.Timeout, requests.exceptions.ConnectionError):
            if method != "GET" or attempt == 2:
                raise
            print(f"  {method} {path}: 応答がないのでやり直します（{attempt + 1}回目）")
            time.sleep(10)
    if res.status_code in allow:
        # 許した失敗でも、何が起きたかは残す（409 は「もうある」のことも「まだ出せない」のこともある）
        print(f"  {method} {path} -> {res.status_code}: {res.text[:3000]}")
        return None
    if res.status_code >= 400:
        print(f"::error::{method} {path} -> {res.status_code}\n{res.text}")
        sys.exit(1)
    return res.json() if res.content else {}


def api_all(path, params=None):
    """ページに分かれた一覧を最後まで読む"""
    items, url, query = [], path, dict(params or {})
    while url:
        res = api("GET", url, params=query)
        items += res["data"]
        url, query = (res.get("links") or {}).get("next"), None
    return items


def upload_parts(operations, blob):
    for op in operations:
        chunk = blob[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        r = requests.request(op["method"], op["url"], data=chunk, headers=headers, timeout=300)
        if r.status_code >= 400:
            sys.exit(f"::error::アップロードに失敗: {r.status_code} {r.text}")


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
        print(f"  既存のバージョン {v['attributes']['versionString']}: {state_of(v)}")
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
    created["attributes"].setdefault("versionString", version_string)
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
    # サポート URL は審査に出すのに要る。書いていなければ、今ある言語のものを使う（新しい言語にはまだない）
    fallback_support = next((l["attributes"].get("supportUrl") for l in locs if l["attributes"].get("supportUrl")), None)
    for locale, section in (cfg.get("localizations") or {}).items():
        loc = by_locale.get(locale)
        wanted = pick(section, VERSION_FIELDS)
        if "supportUrl" not in wanted and fallback_support and not (loc and loc["attributes"].get("supportUrl")):
            wanted["supportUrl"] = fallback_support
        if not loc:
            # 新しい言語（韓国語・中国語など）は、ここで足す。アプリ情報（名前）は update_app_info が先に足しておく
            print(f"{locale}: ストア情報を追加")
            res = api("POST", "/v1/appStoreVersionLocalizations", {"data": {
                "type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **wanted},
                "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
            by_locale[locale] = res["data"]
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
        if not wanted:
            continue
        if not loc:
            # 言語を足すときは、名前が要る
            if not wanted.get("name"):
                print(f"::warning::{locale} のアプリ情報がなく、name もないので足せません")
                continue
            print(f"{locale} アプリ情報: 追加")
            api("POST", "/v1/appInfoLocalizations", {"data": {
                "type": "appInfoLocalizations", "attributes": {"locale": locale, **wanted},
                "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
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
            upload_parts(preview["attributes"]["uploadOperations"], blob)
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


def ensure_purchase(app_id, spec, root):
    """create_purchases に書いた買い切りなどの課金アイテムを作り、名前・価格・販売地域・審査用スクリーンショットをそろえる"""
    pid = spec["product_id"]
    iap_ref = lambda iid: {"data": {"type": "inAppPurchases", "id": iid}}
    existing = [i for i in api_all(f"/v1/apps/{app_id}/inAppPurchasesV2", {"limit": 200})
                if i["attributes"]["productId"] == pid]
    if existing:
        iap = existing[0]
    else:
        print(f"課金アイテム {pid} を作成")
        iap = api("POST", "/v2/inAppPurchases", {"data": {
            "type": "inAppPurchases",
            "attributes": {"name": spec["reference_name"], "productId": pid,
                           "inAppPurchaseType": spec.get("type", "NON_CONSUMABLE"),
                           "familySharable": bool(spec.get("family_sharable", False)),
                           "reviewNote": (spec.get("review_note") or "").rstrip("\n") or None},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
    iid = iap["id"]
    if iid == "DRY":
        return

    locs = {l["attributes"]["locale"]: l for l in api("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations")["data"]}
    for locale, l in (spec.get("localizations") or {}).items():
        wanted = {"name": l["name"], "description": l["description"]}
        if locale in locs:
            diff = changed(locs[locale]["attributes"], wanted)
            if diff:
                print(f"{pid} {locale}: {', '.join(diff)} を更新")
                api("PATCH", f"/v1/inAppPurchaseLocalizations/{locs[locale]['id']}", {"data": {
                    "type": "inAppPurchaseLocalizations", "id": locs[locale]["id"], "attributes": diff}})
        else:
            print(f"{pid} {locale}: 表示名と説明を追加")
            api("POST", "/v1/inAppPurchaseLocalizations", {"data": {
                "type": "inAppPurchaseLocalizations", "attributes": {"locale": locale, **wanted},
                "relationships": {"inAppPurchaseV2": iap_ref(iid)}}})

    availability = api("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseAvailability", allow=(404,))
    if not (availability or {}).get("data"):
        territories = api_all("/v1/territories", {"limit": 200})
        print(f"{pid}: すべての国と地域（{len(territories)}）で販売")
        api("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
            "type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
            "relationships": {"inAppPurchase": iap_ref(iid),
                              "availableTerritories": {"data": [{"type": "territories", "id": t["id"]} for t in territories]}}}})

    if spec.get("price_jpy"):
        want = float(spec["price_jpy"])
        current = None
        schedule = api("GET", f"/v2/inAppPurchases/{iid}/iapPriceSchedule", allow=(404,))
        if (schedule or {}).get("data"):
            res = api("GET", f"/v1/inAppPurchasePriceSchedules/{schedule['data']['id']}/manualPrices",
                      params={"include": "inAppPurchasePricePoint", "filter[territory]": "JPN"})
            points = [i for i in res.get("included", []) if i["type"] == "inAppPurchasePricePoints"]
            if points:
                current = float(points[0]["attributes"]["customerPrice"])
        if current != want:
            points = api_all(f"/v2/inAppPurchases/{iid}/pricePoints", {"filter[territory]": "JPN", "limit": 200})
            point = next((p for p in points if float(p["attributes"]["customerPrice"]) == want), None)
            if not point:
                sys.exit(f"::error::{pid}: 日本で {spec['price_jpy']} 円の価格帯が見つかりません")
            print(f"{pid}: 価格を {spec['price_jpy']} 円に設定（ほかの国は Apple が自動で換算）")
            api("POST", "/v1/inAppPurchasePriceSchedules", {
                "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
                    "inAppPurchase": iap_ref(iid),
                    "baseTerritory": {"data": {"type": "territories", "id": "JPN"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price}"}]}}},
                "included": [{"type": "inAppPurchasePrices", "id": "${price}",
                              "attributes": {"startDate": None},
                              "relationships": {"inAppPurchaseV2": iap_ref(iid),
                                                "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": point["id"]}}}}]})

    shot = spec.get("review_screenshot")
    if not shot:
        return
    path = os.path.join(root, shot)
    if not os.path.exists(path):
        print(f"::warning::{pid}: 審査用スクリーンショット {shot} がまだないので、審査には出せません")
        return
    blob = open(path, "rb").read()
    name = os.path.basename(path)
    res = api("GET", f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot", allow=(404,))
    old = (res or {}).get("data")
    if old:
        attrs = old["attributes"]
        delivery = attrs.get("assetDeliveryState") or {}
        print(f"{pid}: 今の審査用スクリーンショット {attrs.get('fileName')} {attrs.get('fileSize')} bytes, {delivery}")
        # Apple は受け取ったファイルの名前を "SOURCE" に変えるので、大きさで同じものかを見る
        if attrs.get("fileSize") == len(blob) and delivery.get("state") != "FAILED":
            return
    if old:
        api("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{old['id']}")
    print(f"{pid}: 審査用スクリーンショットをアップロード")
    created = api("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "attributes": {"fileName": name, "fileSize": len(blob)},
        "relationships": {"inAppPurchaseV2": iap_ref(iid)}}})["data"]
    if DRY:
        return
    upload_parts(created["attributes"]["uploadOperations"], blob)
    api("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{created['id']}", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": created["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})


def check_purchases(app_id, wanted_ids):
    """Pro の課金アイテムが App Store Connect にあって、審査に出せる状態かを確かめる"""
    if not wanted_ids:
        return []
    found = {}
    for item in api("GET", f"/v1/apps/{app_id}/inAppPurchasesV2", params={"limit": 200})["data"]:
        found[item["attributes"]["productId"]] = ("inAppPurchaseSubmissions", "inAppPurchaseV2", "inAppPurchases", item)
    groups = api("GET", f"/v1/apps/{app_id}/subscriptionGroups", params={"limit": 50})["data"]
    for group in groups:
        for item in api("GET", f"/v1/subscriptionGroups/{group['id']}/subscriptions", params={"limit": 50})["data"]:
            found[item["attributes"]["productId"]] = ("subscriptionSubmissions", "subscription", "subscriptions", item)
    to_submit, ok = [], True
    for pid in wanted_ids:
        if pid not in found:
            print(f"::error::課金アイテム {pid} が App Store Connect にありません")
            ok = False
            continue
        kind, rel, rel_type, item = found[pid]
        state = item["attributes"].get("state")
        print(f"課金アイテム {pid}: {state}")
        if state == "READY_TO_SUBMIT":
            to_submit.append((kind, rel, rel_type, item["id"]))
        elif state in ("MISSING_METADATA", "DEVELOPER_ACTION_NEEDED", "REJECTED"):
            print(f"::warning::{pid} は {state}。App Store Connect で説明・価格・審査用スクリーンショットを埋めてください")
            ok = False
    if not ok:
        print("::warning::課金アイテムに直すところがあります（上を見てください）")
    return to_submit


def ensure_family_sharing(app_id, wanted_ids):
    """サブスクのファミリー共有をオンにする。Apple の決まりで、一度オンにすると開発者は戻せない
    （家族と分けるかどうかは、買った人が iPhone の設定で選べる）"""
    for group in api("GET", f"/v1/apps/{app_id}/subscriptionGroups", params={"limit": 50})["data"]:
        for item in api("GET", f"/v1/subscriptionGroups/{group['id']}/subscriptions", params={"limit": 50})["data"]:
            pid = item["attributes"]["productId"]
            if pid not in wanted_ids:
                continue
            if item["attributes"].get("familySharable"):
                print(f"ファミリー共有 {pid}: オン")
            elif DRY:
                print(f"::notice::ファミリー共有 {pid}: オフ。マージするとオンにします（一度オンにすると戻せません）")
            else:
                api("PATCH", f"/v1/subscriptions/{item['id']}", {"data": {
                    "type": "subscriptions", "id": item["id"], "attributes": {"familySharable": True}}})
                print(f"ファミリー共有 {pid}: オンにしました")


def submit_purchases(items):
    for kind, rel, rel_type, item_id in items:
        res = api("POST", f"/v1/{kind}", {"data": {
            "type": kind, "relationships": {rel: {"data": {"type": rel_type, "id": item_id}}}}}, allow=(409,))
        if res is None:
            # 最初の買い切りアイテムは、App Store Connect の画面でバージョンに追加してからでないと出せない（API にその操作がない）
            print(f"::warning::課金アイテム {item_id} は単独では審査に出せませんでした（上の 409 を参照）。"
                  "最初の買い切りは、App Store Connect のバージョンの画面「App 内課金とサブスクリプション」で追加して、バージョンと一緒に出してください")
            continue
        print(f"課金アイテム {item_id} を審査に出しました")


def screenshot_changes(by_locale, cfg, root):
    """screenshots に書いた画像と、App Store Connect に今ある画像を比べて、入れ替えが要る枠を返す"""
    changes = []
    for locale, sets in (cfg.get("screenshots") or {}).items():
        loc = by_locale.get(locale)
        if not loc:
            print(f"::warning::{locale} のストア情報がないのでスクリーンショットを飛ばします")
            continue
        existing = api("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
        for display_type, rel_paths in sets.items():
            files = [os.path.join(root, p) for p in rel_paths]
            sizes = [os.path.getsize(f) for f in files]
            sset = next((x for x in existing if x["attributes"]["screenshotDisplayType"] == display_type), None)
            current = []
            if sset:
                current = api("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots")["data"]
            if [c["attributes"]["fileSize"] for c in current] == sizes:
                print(f"{locale} {display_type} スクリーンショット: 変更なし（{len(sizes)} 枚）")
                continue
            print(f"{locale} {display_type} スクリーンショット: {len(current)} 枚 → {len(files)} 枚に入れ替え")
            changes.append({"loc": loc, "type": display_type, "set": sset, "current": current, "files": files})
        # remove_other_screenshots: true のときは、書いていない枠（古い 6.5 インチなど）の画像を消す
        if cfg.get("remove_other_screenshots"):
            for sset in existing:
                display_type = sset["attributes"]["screenshotDisplayType"]
                if display_type in sets:
                    continue
                current = api("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots")["data"]
                if current:
                    print(f"{locale} {display_type} スクリーンショット: 書いていない枠なので {len(current)} 枚を消す")
                    changes.append({"loc": loc, "type": display_type, "set": sset, "current": current, "files": []})
    return changes


def replace_screenshots(changes):
    uploaded = []
    for change in changes:
        sset = change["set"]
        if not sset:
            sset = api("POST", "/v1/appScreenshotSets", {"data": {
                "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": change["type"]},
                "relationships": {"appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": change["loc"]["id"]}}}}})["data"]
        for old in change["current"]:
            api("DELETE", f"/v1/appScreenshots/{old['id']}")
        if not change["files"]:
            print(f"{change['loc']['attributes']['locale']} {change['type']}: {len(change['current'])} 枚を消しました")
            continue
        ids = []
        for path in change["files"]:
            blob = open(path, "rb").read()
            shot = api("POST", "/v1/appScreenshots", {"data": {
                "type": "appScreenshots", "attributes": {"fileName": os.path.basename(path), "fileSize": len(blob)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
            if DRY:
                continue
            upload_parts(shot["attributes"]["uploadOperations"], blob)
            api("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {
                "type": "appScreenshots", "id": shot["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
            ids.append(shot["id"])
        if ids:
            # 書いた順に並べる（1〜3枚目が検索結果に出る）
            api("PATCH", f"/v1/appScreenshotSets/{sset['id']}/relationships/appScreenshots",
                {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
        uploaded += ids
        print(f"{change['loc']['attributes']['locale']} {change['type']}: {len(change['files'])} 枚をアップロード")
    return uploaded


def wait_screenshots(ids, minutes=20):
    deadline = time.time() + minutes * 60
    for sid in ids:
        while True:
            attrs = api("GET", f"/v1/appScreenshots/{sid}")["data"]["attributes"]
            state = (attrs.get("assetDeliveryState") or {}).get("state")
            if state == "COMPLETE":
                break
            if state == "FAILED" or time.time() > deadline:
                sys.exit(f"::error::スクリーンショットの処理が終わりません: {attrs.get('fileName')} {attrs.get('assetDeliveryState')}")
            time.sleep(10)
    if ids:
        print(f"スクリーンショット {len(ids)} 枚の処理が終わりました")


def withdraw(app_id, version):
    """審査待ちのバージョンを取り下げて、中身を変えられる状態に戻す"""
    subs = api("GET", "/v1/reviewSubmissions", params={
        "filter[app]": app_id, "filter[platform]": "IOS", "filter[state]": "WAITING_FOR_REVIEW"})["data"]
    if not subs:
        sys.exit("::error::取り下げられる審査が見つかりません")
    for sub in subs:
        print(f"審査を取り下げます（{sub['id']}）")
        api("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {
            "type": "reviewSubmissions", "id": sub["id"], "attributes": {"canceled": True}}})
    if DRY:
        return
    deadline = time.time() + 600
    while time.time() < deadline:
        current = api("GET", f"/v1/appStoreVersions/{version['id']}")["data"]
        state = state_of(current)
        if state in EDITABLE:
            print(f"取り下げました（{state}）")
            version["attributes"] = current["attributes"]
            return
        print(f"取り下げ待ち（{state}）…")
        time.sleep(15)
    sys.exit("::error::取り下げが終わりません")


def submit(app_id, version_id, event_ids=()):
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
    # 一緒に出すイベント（審査に入れられないものは 409 を残して続ける）
    for eid in event_ids:
        api("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
            "appEvent": {"data": {"type": "appEvents", "id": eid}}}}}, allow=(409,))
    # バージョンが入っていない審査を出そうとすると「does not have any items」で止まる。入っているか確かめてから出す
    items = api("GET", f"/v1/reviewSubmissions/{sub['id']}/items", params={"include": "appStoreVersion"})["data"]
    if not DRY and not any((i.get("relationships") or {}).get("appStoreVersion", {}).get("data", {}).get("id") == version_id for i in items):
        sys.exit(f"::error::審査（{sub['id']}）にバージョンを入れられませんでした。上の 409 の内容を確認してください")
    api("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {
        "type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print("審査に提出しました")


# MARK: - App 内イベント（release.yml の events）

EVENT_FIELDS = {"name": "name", "short": "shortDescription", "long": "longDescription"}
EVENT_EDITABLE = {"DRAFT", "READY_FOR_REVIEW", "REJECTED", "DEVELOPER_REJECTED"}
_territories = None


def all_territories():
    global _territories
    if _territories is None:
        _territories = [t["id"] for t in api_all("/v1/territories", params={"limit": 200})]
    return _territories


def parse_time(value):
    from datetime import datetime
    return datetime.fromisoformat(str(value))


def check_event(ev):
    """Apple の決まり：期間は31日まで、ストアに出すのは始まる14日前から。名前30・短い説明50・長い説明120文字まで"""
    start, end, publish = parse_time(ev["start"]), parse_time(ev["end"]), parse_time(ev["publish"])
    if (end - start).days > 31:
        sys.exit(f"::error::イベント {ev['ref']}: 期間が31日を超えています")
    if (start - publish).days > 14 or publish > start:
        sys.exit(f"::error::イベント {ev['ref']}: ストアに出す日は、始まる14日前から始まる日までにしてください")
    for locale, text in ev["localizations"].items():
        for key, limit in (("name", 30), ("short", 50), ("long", 120)):
            if len(text.get(key, "")) > limit:
                sys.exit(f"::error::イベント {ev['ref']} {locale}: {key} が {limit} 文字を超えています")


def iso(value):
    return parse_time(value).isoformat()


def upload_event_asset(loc_id, kind, path):
    blob = open(path, "rb").read()
    shot = api("POST", "/v1/appEventScreenshots", {"data": {
        "type": "appEventScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(blob), "appEventAssetType": kind},
        "relationships": {"appEventLocalization": {"data": {"type": "appEventLocalizations", "id": loc_id}}}}})["data"]
    if DRY:
        return
    upload_parts(shot["attributes"]["uploadOperations"], blob)
    api("PATCH", f"/v1/appEventScreenshots/{shot['id']}", {"data": {
        "type": "appEventScreenshots", "id": shot["id"], "attributes": {"uploaded": True}}})


def sync_events(app_id, cfg, root):
    """events に書いたイベントを作る・直す。ストアの決まりに合わないものは止める。返すのは審査に出すイベントの id"""
    events = cfg.get("events") or []
    if not events:
        return []
    existing = {e["attributes"]["referenceName"]: e for e in api_all(f"/v1/apps/{app_id}/appEvents", params={"limit": 200})}
    to_submit = []
    for ev in events:
        check_event(ev)
        attrs = {
            "referenceName": ev["ref"], "badge": ev["badge"], "purpose": ev.get("purpose", "APPROPRIATE_FOR_ALL_USERS"),
            "priority": ev.get("priority", "NORMAL"), "primaryLocale": ev.get("primary_locale", "ja"),
            # 参加にお金が要るか。StudyReel のイベントは無料で参加できる
            "purchaseRequirement": ev.get("purchase", "NO_COST_ASSOCIATED"),
            # 審査に出すのに要る。アプリが知らない host なので、開くとホームが出る（studyreel://start は勉強が始まってしまうので使わない）
            "deepLink": ev.get("deep_link", f"studyreel://event/{ev['ref']}"),
            "territorySchedules": [{"territories": all_territories(), "publishStart": iso(ev["publish"]),
                                    "eventStart": iso(ev["start"]), "eventEnd": iso(ev["end"])}],
        }
        current = existing.get(ev["ref"])
        if not current:
            print(f"イベント {ev['ref']}: 作成")
            current = api("POST", "/v1/appEvents", {"data": {"type": "appEvents", "attributes": attrs,
                          "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
        state = (current.get("attributes") or {}).get("eventState") or "DRAFT"
        if state not in EVENT_EDITABLE:
            print(f"イベント {ev['ref']}: {state} なので変えません")
            continue
        if current["id"] != "DRY" and ev["ref"] in existing:
            api("PATCH", f"/v1/appEvents/{current['id']}", {"data": {"type": "appEvents", "id": current["id"],
                "attributes": {k: v for k, v in attrs.items() if k != "referenceName"}}})
        locs = {} if current["id"] == "DRY" else {
            l["attributes"]["locale"]: l for l in api_all(f"/v1/appEvents/{current['id']}/localizations")}
        for locale, text in ev["localizations"].items():
            wanted = pick(text, EVENT_FIELDS)
            loc = locs.get(locale)
            if not loc:
                print(f"イベント {ev['ref']} {locale}: 文言を追加")
                loc = api("POST", "/v1/appEventLocalizations", {"data": {"type": "appEventLocalizations",
                          "attributes": {"locale": locale, **wanted},
                          "relationships": {"appEvent": {"data": {"type": "appEvents", "id": current["id"]}}}}})["data"]
            else:
                diff = changed(loc["attributes"], wanted)
                if diff:
                    print(f"イベント {ev['ref']} {locale}: {', '.join(diff)} を更新")
                    api("PATCH", f"/v1/appEventLocalizations/{loc['id']}", {"data": {
                        "type": "appEventLocalizations", "id": loc["id"], "attributes": diff}})
            # 画像は、まだないときだけ上げる（差し替えたいときは App Store Connect で消してから）
            have = set()
            if loc["id"] != "DRY":
                have = {a["attributes"].get("appEventAssetType")
                        for a in api_all(f"/v1/appEventLocalizations/{loc['id']}/appEventScreenshots")}
            for kind, key in (("EVENT_CARD", "card"), ("EVENT_DETAILS_PAGE", "detail")):
                if kind not in have and ev.get(key):
                    print(f"イベント {ev['ref']} {locale}: {kind} の画像を上げる")
                    upload_event_asset(loc["id"], kind, os.path.join(root, ev[key]))
        if ev.get("submit"):
            to_submit.append(current["id"])
    return to_submit


def events_to_submit(app_id, cfg):
    """submit: true で、もう作ってあり、まだ審査に出していないイベント（作るのは events_only で先にしておく）"""
    wanted = {ev["ref"] for ev in cfg.get("events") or [] if ev.get("submit")}
    if not wanted:
        return []
    ids = []
    for e in api_all(f"/v1/apps/{app_id}/appEvents", params={"limit": 200}):
        a = e["attributes"]
        if a.get("referenceName") in wanted and a.get("eventState") in {"DRAFT", "READY_FOR_REVIEW", "REJECTED", "DEVELOPER_REJECTED"}:
            ids.append(e["id"])
            print(f"イベント {a['referenceName']} もバージョンと一緒に審査に出します")
    return ids


def submit_events(app_id, event_ids):
    """イベントだけで審査に出す（バージョンがもう審査中・公開中のとき）"""
    if not event_ids or DRY:
        if event_ids:
            print(f"[dry-run] イベント {len(event_ids)} 件を審査に出します")
        return
    subs = api("GET", "/v1/reviewSubmissions", params={
        "filter[app]": app_id, "filter[platform]": "IOS", "filter[state]": "READY_FOR_REVIEW,UNRESOLVED_ISSUES"})["data"]
    sub = subs[0] if subs else api("POST", "/v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
    for eid in event_ids:
        api("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
            "appEvent": {"data": {"type": "appEvents", "id": eid}}}}}, allow=(409,))
    # 入れられなかったときに「出しました」と言わない
    items = api("GET", f"/v1/reviewSubmissions/{sub['id']}/items")["data"]
    if not items:
        sys.exit(f"::error::審査（{sub['id']}）にイベントを入れられませんでした。上の 409 の内容を確認してください")
    api("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {
        "type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print(f"イベント {len(items)} 件を審査に出しました")


def show_current(app_id):
    """dry run のとき、いま App Store に出ている版の文言を出す（ASO の見直しで今の値と比べるため）"""
    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions",
                   params={"filter[platform]": "IOS", "filter[appStoreState]": "READY_FOR_SALE", "limit": 1})["data"]
    print("::group::いまのストアの文言")
    if versions:
        v = versions[0]
        print(f"公開中のバージョン {v['attributes']['versionString']}")
        for loc in api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]:
            a = loc["attributes"]
            print(f"--- {a['locale']}")
            for key in ("keywords", "promotionalText", "description"):
                print(f"[{key}]\n{a.get(key) or ''}")
    infos = api("GET", f"/v1/apps/{app_id}/appInfos")["data"]
    for info in infos:
        cat = api("GET", f"/v1/appInfos/{info['id']}/primaryCategory").get("data") or {}
        print(f"アプリ情報（{info['attributes'].get('state') or info['attributes'].get('appStoreState')}） カテゴリ: {cat.get('id')}")
        for loc in api("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]:
            a = loc["attributes"]
            print(f"  {a['locale']}: name={a.get('name')!r} subtitle={a.get('subtitle')!r}")
    print("::endgroup::")


def main():
    cfg_path = next(a for a in sys.argv[1:] if not a.startswith("--"))
    cfg = yaml.safe_load(open(cfg_path))
    root = os.path.dirname(os.path.dirname(os.path.abspath(cfg_path)))
    if DRY:
        print("dry run: App Store Connect は読むだけで、何も変えません")

    app_id = find_app(cfg["app"])
    if DRY:
        show_current(app_id)
    for ev in cfg.get("events") or []:
        check_event(ev)
    if EVENTS_ONLY:
        # 作る・直す。submit: true のものは、イベントだけで審査に出す（バージョンが審査中のときは出せないので、そのときは次に回る）
        ids = sync_events(app_id, cfg, root)
        if "--submit-events" in sys.argv:
            submit_events(app_id, ids)
        return
    for spec in cfg.get("create_purchases") or []:
        ensure_purchase(app_id, spec, root)
    purchases = check_purchases(app_id, cfg.get("purchases") or [])
    if cfg.get("family_sharing"):
        ensure_family_sharing(app_id, cfg.get("purchases") or [])
    version, versions = find_or_create_version(app_id, str(cfg["version"]))
    state = state_of(version)
    print(f"バージョン {version['attributes']['versionString']}: {state}")
    if RELEASE_NOW:
        if state != "PENDING_DEVELOPER_RELEASE":
            sys.exit(f"::error::バージョン {cfg['version']} は {state} なので公開できません（承認済みのときだけ公開できます）")
        if DRY:
            print("[dry-run] 公開はしません")
            return
        api("POST", "/v1/appStoreVersionReleaseRequests", {"data": {
            "type": "appStoreVersionReleaseRequests",
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
        print(f"バージョン {cfg['version']} を公開しました（ストアに出るまで数時間かかることがあります）")
        return
    # 審査待ちでも、スクリーンショットやビルドを入れ替えたいときは取り下げてから直す（withdraw_to_update: true のとき）
    if state == "WAITING_FOR_REVIEW" and cfg.get("withdraw_to_update"):
        locs = api("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
        shots_changed = screenshot_changes({l["attributes"]["locale"]: l for l in locs}, cfg, root)
        # 新しいビルドは処理が終わってから取り下げる（使えないビルドのために審査を止めない）
        build = find_build(app_id, cfg, wait_minutes=0 if DRY else 30)
        current = api("GET", f"/v1/appStoreVersions/{version['id']}/relationships/build")
        build_changed = (current.get("data") or {}).get("id") != build["id"]
        if build_changed:
            print(f"ビルドを {build['attributes']['version']} に差し替えます")
        if shots_changed or build_changed:
            withdraw(app_id, version)
            state = "DEVELOPER_REJECTED"
            # 一緒に取り下がった課金アイテムも、もう一度出せるように数え直す
            purchases = check_purchases(app_id, cfg.get("purchases") or [])
    if state in IN_REVIEW or state == "READY_FOR_DISTRIBUTION":
        print("このバージョンはもう審査に出ているので、バージョンの中身は変えません")
        # あとから準備ができた課金アイテムだけ、追いかけて審査に出す
        if purchases and cfg.get("submit_for_review"):
            if DRY:
                print(f"submit_for_review: true なので、マージすると課金アイテム {len(purchases)} 件を審査に出します")
            else:
                submit_purchases(purchases)
        return
    if version["id"] == "DRY":
        print("（dry run なので、これから作るバージョンの中身は確かめられません）")
        return

    update_version_attributes(version, cfg)
    # 新しい言語は、アプリ情報（名前）を先に足してから、バージョンの文言を足す
    update_app_info(app_id, cfg)
    by_locale = update_localizations(version["id"], cfg)
    build = find_build(app_id, cfg, wait_minutes=0 if DRY else 30)
    attach_build(version["id"], build)
    update_review_detail(version["id"], versions, cfg)
    previews = upload_previews(by_locale, cfg, root)
    shots = replace_screenshots(screenshot_changes(by_locale, cfg, root))

    if cfg.get("submit_for_review"):
        if DRY:
            print("submit_for_review: true なので、マージすると審査に出します")
            return
        wait_previews(previews)
        wait_screenshots(shots)
        submit_purchases(purchases)
        submit(app_id, version["id"], events_to_submit(app_id, cfg))
    else:
        print("submit_for_review: false なので、審査には出していません")


if __name__ == "__main__":
    main()
