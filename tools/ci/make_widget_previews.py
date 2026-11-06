#!/usr/bin/env python3
"""Genera las vistas previas de los widgets para el selector de Android.

Salida: tools/ci/widget/widget_player_preview.png y widget_shortcuts_preview.png.
Solo hace falta volver a correrlo si cambia el diseño de los widgets.
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "widget")
SS = 4  # supersampling
ACCENT = (255, 87, 34, 255)
PANEL = (18, 18, 18, 230)
SOFT = (255, 255, 255, 36)
TEXT = (255, 255, 255, 235)
DIM = (255, 255, 255, 120)


def note(draw, box, color):
    """Nota musical sencilla dentro de [box] = (x, y, lado)."""
    x, y, side = box
    stem = max(2, side // 11)
    top = y + side * 0.16
    right = x + side * 0.70
    draw.rectangle([right - stem, top, right, y + side * 0.74], fill=color)
    draw.polygon(
        [
            (right, top),
            (x + side * 0.88, top + side * 0.10),
            (x + side * 0.88, top + side * 0.28),
            (right, top + side * 0.18),
        ],
        fill=color,
    )
    radius = side * 0.15
    draw.ellipse(
        [right - stem - radius * 2, y + side * 0.60, right - stem, y + side * 0.60 + radius * 2],
        fill=color,
    )


def circle(draw, cx, cy, radius, fill):
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=fill)


def triangle(draw, cx, cy, size, color, pointing=1):
    """Triángulo de reproducción; [pointing] -1 lo apunta a la izquierda."""
    draw.polygon(
        [
            (cx - pointing * size * 0.35, cy - size * 0.55),
            (cx - pointing * size * 0.35, cy + size * 0.55),
            (cx + pointing * size * 0.55, cy),
        ],
        fill=color,
    )


def skip(draw, cx, cy, size, color, forward=True):
    """Botón de anterior/siguiente: triángulo + barrita del lado del tope."""
    direction = 1 if forward else -1
    bar = max(2, size * 0.18)
    triangle(draw, cx - direction * size * 0.15, cy, size * 0.9, color, direction)
    edge = cx + direction * size * 0.45
    draw.rectangle(
        [min(edge, edge + direction * bar), cy - size * 0.5,
         max(edge, edge + direction * bar), cy + size * 0.5],
        fill=color,
    )


def panel(draw, width, height, radius):
    draw.rounded_rectangle([0, 0, width - 1, height - 1], radius=radius, fill=PANEL)


def player_preview(width=320, height=140):
    image = Image.new("RGBA", (width * SS, height * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    w, h = width * SS, height * SS
    panel(draw, w, h, 22 * SS)

    pad = 14 * SS
    art = h - pad * 2
    draw.rounded_rectangle([pad, pad, pad + art, pad + art], radius=art * 0.18, fill=SOFT)
    note(draw, (pad + art * 0.18, pad + art * 0.18, art * 0.64), ACCENT)

    left = pad + art + 12 * SS
    draw.rounded_rectangle(
        [left, pad + 6 * SS, left + 98 * SS, pad + 18 * SS], radius=6 * SS, fill=TEXT
    )
    draw.rounded_rectangle(
        [left, pad + 26 * SS, left + 70 * SS, pad + 35 * SS], radius=5 * SS, fill=DIM
    )

    cy = pad + art - 16 * SS
    radius = 19 * SS
    circle(draw, left + radius, cy, radius, SOFT)
    skip(draw, left + radius, cy, radius * 0.7, TEXT, forward=False)
    cx2 = left + radius * 3 + 8 * SS
    circle(draw, cx2, cy, radius * 1.1, SOFT)
    triangle(draw, cx2, cy, radius * 0.95, ACCENT)
    cx3 = cx2 + radius * 2.3 + 8 * SS
    circle(draw, cx3, cy, radius, SOFT)
    skip(draw, cx3, cy, radius * 0.7, TEXT, forward=True)
    return image.resize((width, height), Image.LANCZOS)


def shortcuts_preview(width=320, height=80):
    image = Image.new("RGBA", (width * SS, height * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    w, h = width * SS, height * SS
    panel(draw, w, h, 22 * SS)
    radius = 24 * SS
    gap = (w - 8 * radius) / 5
    cy = h / 2
    for i in range(4):
        cx = gap * (i + 1) + radius * (2 * i + 1)
        circle(draw, cx, cy, radius, SOFT)
        if i == 0:
            triangle(draw, cx, cy, radius * 0.9, ACCENT)
        elif i == 1:
            bar = radius * 0.16
            for sign in (-1, 1):
                draw.line(
                    [(cx - radius * 0.5, cy + sign * radius * 0.3),
                     (cx + radius * 0.5, cy - sign * radius * 0.3)],
                    fill=ACCENT, width=int(bar),
                )
        elif i == 2:
            r = radius * 0.3
            circle(draw, cx - r * 0.8, cy - r * 0.4, r, ACCENT)
            circle(draw, cx + r * 0.8, cy - r * 0.4, r, ACCENT)
            draw.polygon(
                [(cx - r * 1.75, cy - r * 0.1), (cx + r * 1.75, cy - r * 0.1),
                 (cx, cy + r * 1.7)], fill=ACCENT,
            )
        else:
            r = radius * 0.42
            draw.ellipse([cx - r - r * 0.3, cy - r - r * 0.3, cx + r - r * 0.3, cy + r - r * 0.3],
                         outline=ACCENT, width=int(radius * 0.16))
            draw.line([(cx + r * 0.3, cy + r * 0.3), (cx + r * 0.95, cy + r * 0.95)],
                      fill=ACCENT, width=int(radius * 0.16))
    return image.resize((width, height), Image.LANCZOS)


os.makedirs(OUT, exist_ok=True)
player_preview().save(os.path.join(OUT, "widget_player_preview.png"))
shortcuts_preview().save(os.path.join(OUT, "widget_shortcuts_preview.png"))
print("Vistas previas generadas en", OUT)
