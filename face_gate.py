import os
import time
from typing import List, Optional, Tuple

import cv2
import numpy as np
import face_recognition
from PIL import Image, ImageDraw, ImageFont
import firebase_admin
from firebase_admin import credentials, firestore

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 1. Firebase Admin SDK
print("[SISTEM] Firebase baglantisi kuruluyor...")
cred = credentials.Certificate(os.path.join(BASE_DIR, "serviceAccountKey.json"))
firebase_admin.initialize_app(cred)
db = firestore.client()

# 2. Taninacak yuzler (melikan.jpeg + mert.jpeg)


def _load_face_encoding(image_path: str):
    image = face_recognition.load_image_file(image_path)
    encodings = face_recognition.face_encodings(image)
    if not encodings:
        raise ValueError(f"Yuz bulunamadi: {image_path}")
    return encodings[0]


print("[SISTEM] Yuz modelleri hafizaya aliniyor...")
def _overlay_turkish_lines(
    bgr_frame,
    lines: List[Tuple[str, Tuple[int, int, int]]],
    start_y: int = 36,
):
    """OpenCV varsayilan fontu Turkce desteklemez; PIL ile RGB uzerine yazar."""
    rgb = cv2.cvtColor(bgr_frame, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(rgb)
    draw = ImageDraw.Draw(pil_img)
    try:
        font = ImageFont.truetype(
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            26,
        )
    except OSError:
        font = ImageFont.load_default()
    y = start_y
    for text, color_rgb in lines:
        draw.text((28, y), text, fill=color_rgb, font=font)
        y += 34
    return cv2.cvtColor(np.asarray(pil_img), cv2.COLOR_RGB2BGR)


KNOWN_CONFIG = [
    ("melikan.jpeg", "Melikan"),
    ("mert.jpeg", "Mert"),
]
known_face_encodings = []
known_face_names = []

try:
    for filename, display_name in KNOWN_CONFIG:
        path = os.path.join(BASE_DIR, filename)
        if not os.path.isfile(path):
            raise FileNotFoundError(f"Dosya yok: {path}")
        known_face_encodings.append(_load_face_encoding(path))
        known_face_names.append(display_name)
    print("[SISTEM] Yuz modelleri basariyla yuklendi:", ", ".join(known_face_names))
except Exception as e:
    print(f"[HATA] Referans yuzler yuklenemedi: {e}")
    raise SystemExit(1) from e

# 3. Kamera
video_capture = cv2.VideoCapture(0)
print("[SISTEM] Kamera aktif. Turnike yuz tanima modu devrede... (cikis: q)")

cooldown_until = 0.0
last_passed_name: Optional[str] = None

while True:
    ret, frame = video_capture.read()
    if not ret:
        print("[HATA] Kameradan goruntu alinamadi.")
        break

    current_time = time.time()

    # Cooldown: son gecisten sonra kisa sure bilgi goster, sonra normale don
    if current_time < cooldown_until:
        lines: List[Tuple[str, Tuple[int, int, int]]] = []
        if last_passed_name:
            lines.append((f"{last_passed_name} geçti!", (40, 200, 120)))
        lines.append(("Geçiş başarılı!", (60, 220, 80)))
        frame = _overlay_turkish_lines(frame, lines)
        cv2.imshow("ADUPass AI Face Gate", frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break
        continue

    last_passed_name = None

    small_frame = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)
    rgb_small_frame = cv2.cvtColor(small_frame, cv2.COLOR_BGR2RGB)

    face_locations = face_recognition.face_locations(rgb_small_frame)
    face_encodings = face_recognition.face_encodings(rgb_small_frame, face_locations)

    matched = False
    for face_encoding in face_encodings:
        matches = face_recognition.compare_faces(
            known_face_encodings,
            face_encoding,
            tolerance=0.45,
        )
        if True not in matches:
            continue

        idx = matches.index(True)
        name = known_face_names[idx]

        print(f"[AI] Yuz tanindi: {name}! Firestore guncelleniyor...")
        try:
            gate_ref = db.collection("gates").document("gate_1")
            gate_ref.set(
                {
                    "status": "success",
                    "studentName": name,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )
            print("[FIRESTORE] gate_1 success olarak guncellendi.")
        except Exception as e:
            print(f"[HATA] Firestore guncellenemedi: {e}")

        last_passed_name = name
        cooldown_until = current_time + 5
        matched = True
        break

    if not matched:
        cv2.putText(
            frame,
            "ADUPass AI Face Gate dinliyor...",
            (30, 35),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.65,
            (255, 165, 0),
            2,
        )

    cv2.imshow("ADUPass AI Face Gate", frame)

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

video_capture.release()
cv2.destroyAllWindows()
