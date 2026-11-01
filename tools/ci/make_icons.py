#!/usr/bin/env python3
"""Genera el ícono de la app (notas musicales blancas sobre naranja).

Salida: tools/ci/icon/res/ (mipmap-*/ic_launcher.png, ic_launcher_foreground.png,
mipmap-anydpi-v26/ic_launcher.xml y values/ic_launcher_background.xml) y
tools/ci/icon/icon_1024.png. Solo hace falta volver a correrlo si cambias el diseño.
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "icon")
ORANGE_TOP = (255, 112, 67)
ORANGE_BOTTOM = (230, 74, 25)
SS = 4  # supersampling

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        color = tuple(round(a + (b - a) * t) for a, b in zip(ORANGE_TOP, ORANGE_BOTTOM))
        for x in range(size):
            px[x, y] = color
    return img


def ellipse_points(cx, cy, rx, ry, angle_deg, n=48):
    a = math.radians(angle_deg)
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    return pts


def draw_notes(size, box):
    """Dibuja ♫ en blanco sobre fondo transparente. `box` = fracción central usada."""
    big = size * SS
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    side = big * box
    ox = oy = (big - side) / 2

    def p(x, y):  # coordenadas 0..100 -> píxeles
        return (ox + x / 100 * side, oy + y / 100 * side)

    white = (255, 255, 255, 255)
    # cabezas de nota
    for cx, cy in ((27, 74), (69, 64)):
        pts = [p(x, y) for x, y in ellipse_points(cx, cy, 14, 10.5, -22)]
        d.polygon(pts, fill=white)
    # plicas (arrancan dentro de la cabeza y llegan hasta la barra)
    d.polygon([p(36, 72), p(42, 72), p(42, 26), p(36, 26)], fill=white)
    d.polygon([p(78, 62), p(84, 62), p(84, 17), p(78, 17)], fill=white)
    # barra
    d.polygon([p(36, 25), p(84, 14), p(84, 29), p(36, 40)], fill=white)
    return layer.resize((size, size), Image.LANCZOS)


def legacy_icon(size):
    big = size * SS
    bg = gradient(big).convert("RGBA")
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big - 1, big - 1), radius=int(big * 0.22), fill=255)
    bg.putalpha(mask)
    notes = draw_notes(big, 0.62)
    bg.alpha_composite(notes)
    return bg.resize((size, size), Image.LANCZOS)


def main():
    res = os.path.join(OUT, "res")
    for density, size in LEGACY.items():
        folder = os.path.join(res, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        legacy_icon(size).save(os.path.join(folder, "ic_launcher.png"))
    for density, size in ADAPTIVE.items():
        folder = os.path.join(res, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        # zona segura del ícono adaptable: círculo central de 66/108
        draw_notes(size, 0.50).save(os.path.join(folder, "ic_launcher_foreground.png"))
    os.makedirs(os.path.join(res, "mipmap-anydpi-v26"), exist_ok=True)
    with open(os.path.join(res, "mipmap-anydpi-v26", "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            "</adaptive-icon>\n"
        )
    os.makedirs(os.path.join(res, "values"), exist_ok=True)
    with open(os.path.join(res, "values", "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#FF5722</color>\n'
            "</resources>\n"
        )
    legacy_icon(1024).save(os.path.join(OUT, "icon_1024.png"))
    print("Íconos generados en", OUT)


if __name__ == "__main__":
    main()
