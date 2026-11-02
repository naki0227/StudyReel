#!/usr/bin/env python3
"""PV の録画とモザイクの場面に使う、タイムラプス動画のコマを作る。

assets/study-timelapse.mp4（Muse で作った 1080×1920・24fps の動画）を1コマずつ JPEG にして、
顔に自動でモザイクをかけたものも作る（アプリと同じく、顔の範囲を少し広げて四角いモザイク）。

  pip install opencv-python-headless
  python3 timelapse.py     # out/timelapse/ と out/timelapse-mosaic/ に 0001.jpg… を書く

顔の検出は OpenCV の YuNet。モデルは初回に out/model/ に取ってくる。
"""
import glob
import os
import subprocess
import urllib.request

import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "assets", "study-timelapse.mp4")
OUT = os.path.join(HERE, "out")
MODEL = os.path.join(OUT, "model", "face_detection_yunet_2023mar.onnx")
MODEL_URL = "https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx"
BLOCK = 30      # モザイクの1マス（px）
GROW = 0.25     # 顔の枠を上下左右に広げる割合
SMOOTH = 2      # 前後何コマで顔の位置をならすか（ちらつかないように）


def main():
    plain = os.path.join(OUT, "timelapse")
    mosaic = os.path.join(OUT, "timelapse-mosaic")
    for d in (plain, mosaic, os.path.dirname(MODEL)):
        os.makedirs(d, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", SRC, "-q:v", "2", os.path.join(plain, "%04d.jpg")], check=True)
    if not os.path.exists(MODEL):
        urllib.request.urlretrieve(MODEL_URL, MODEL)

    files = sorted(glob.glob(os.path.join(plain, "*.jpg")))
    det = cv2.FaceDetectorYN.create(MODEL, "", (1080, 1920), 0.5, 0.3, 5000)
    boxes = []
    for f in files:
        img = cv2.imread(f)
        det.setInputSize((img.shape[1], img.shape[0]))
        _, faces = det.detect(img)
        boxes.append(None if faces is None or len(faces) == 0 else max(faces, key=lambda r: r[14])[:4].tolist())
    # 見つからなかったコマは、近いコマの枠を使う
    for i, b in enumerate(boxes):
        if b is None:
            near = [j for j in range(len(boxes)) if boxes[j] is not None]
            boxes[i] = boxes[min(near, key=lambda j: abs(j - i))] if near else [0, 0, 0, 0]
    for i, f in enumerate(files):
        window = [boxes[j] for j in range(max(0, i - SMOOTH), min(len(boxes), i + SMOOTH + 1))]
        x, y, w, h = [sum(b[k] for b in window) / len(window) for k in range(4)]
        img = cv2.imread(f)
        x0, y0 = max(0, int(x - w * GROW)), max(0, int(y - h * GROW))
        x1, y1 = min(img.shape[1], int(x + w * (1 + GROW))), min(img.shape[0], int(y + h * (1 + GROW)))
        face = img[y0:y1, x0:x1]
        small = cv2.resize(face, (max(1, (x1 - x0) // BLOCK), max(1, (y1 - y0) // BLOCK)), interpolation=cv2.INTER_AREA)
        img[y0:y1, x0:x1] = cv2.resize(small, (x1 - x0, y1 - y0), interpolation=cv2.INTER_NEAREST)
        cv2.imwrite(os.path.join(mosaic, os.path.basename(f)), img, [cv2.IMWRITE_JPEG_QUALITY, 92])
    print(f"{len(files)} frames -> {plain}, {mosaic}")


if __name__ == "__main__":
    main()
