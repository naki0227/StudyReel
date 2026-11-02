#!/usr/bin/env python3
"""アプリの画面（スクショ）の中のサムネイルを、assets の写真に差し替えた画像を作る。

デモの記録は平たいイラストの人なので、PV では写真に置き換える。
位置はスクショ（1320×2868）のピクセルで、画面が変わったら測り直す。

  python3 thumbs.py        # assets/ と assets/en/ に *-photo.png を書く
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, "assets")
PHOTOS = ["tl-morning.jpg", "tl-noon.jpg", "tl-night.jpg", "tl-stretch.jpg"]

# 画面 → [(左, 上, 右, 下, 角の丸み, 写真の番号, 右下の文字)]
SPOTS = {
    "home18.png": [(204, 1990, 1146, 2579, 28, 1, "50m"), (204, 2621, 1146, 3210, 28, 0, "")],
    "share.png": [(126, 1772, 1194, 2222, 24, 1, "")],
    "vlog.png": [(60, 700, 348, 880, 16, 0, ""), (372, 700, 660, 880, 16, 1, ""),
                 (684, 700, 972, 880, 16, 2, ""), (996, 700, 1284, 880, 16, 3, "")],
}


def cover(photo, w, h, focus_y=0.4):
    """写真を w×h に切り抜く（顔が入るように少し上を中心に）"""
    scale = max(w / photo.width, h / photo.height)
    p = photo.resize((round(photo.width * scale), round(photo.height * scale)), Image.LANCZOS)
    left = (p.width - w) // 2
    top = int((p.height - h) * focus_y)
    return p.crop((left, top, left + w, top + h))


def patch(src, dst, spots):
    shot = Image.open(src).convert("RGBA")
    font = ImageFont.truetype(os.path.join(HERE, "fonts", "ZenKakuGothicNew-Medium.ttf"), 30)
    for left, top, right, bottom, radius, index, label in spots:
        w, h = right - left, bottom - top
        photo = cover(Image.open(os.path.join(A, PHOTOS[index])).convert("RGBA"), w, h)
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
        # 画面の下で切れている枠は、切れたまま貼る
        visible = (0, 0, w, min(h, shot.height - top))
        shot.paste(photo.crop(visible), (left, top), mask.crop(visible))
        if label:
            draw = ImageDraw.Draw(shot)
            x, y = right - 26, bottom - 22
            draw.text((x + 1, y + 2), label, font=font, fill=(0, 0, 0, 90), anchor="rd")
            draw.text((x, y), label, font=font, fill=(255, 255, 255, 255), anchor="rd")
    shot.convert("RGB").save(dst)


for name, spots in SPOTS.items():
    for folder in (A, os.path.join(A, "en")):
        src = os.path.join(folder, name)
        if os.path.exists(src):
            patch(src, os.path.join(folder, name.replace(".png", "-photo.png")), spots)
            print("wrote", os.path.join(folder, name.replace(".png", "-photo.png")))
