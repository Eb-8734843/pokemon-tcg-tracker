"""Draws the app icon: a fan of three cards with a gold tick on an indigo gradient.

Writes AppIcon.png (light), AppIcon-Dark.png and AppIcon-Tinted.png at 1024x1024
into the folder given as the first argument. Drawn at 4x and scaled down for
smooth edges.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(sys.argv[1])
SIZE = 1024
S = 4                      # supersampling factor
W = SIZE * S


def gradient(top, bottom):
    """Diagonal gradient from top-left to bottom-right."""
    img = Image.new("RGB", (W, W))
    px = img.load()
    # Build one row of a 1-D gradient, then use it via a diagonal lookup.
    steps = 512
    lut = [tuple(int(top[c] + (bottom[c] - top[c]) * i / (steps - 1)) for c in range(3)) for i in range(steps)]
    small = Image.new("RGB", (steps, steps))
    sp = small.load()
    for y in range(steps):
        for x in range(steps):
            sp[x, y] = lut[min(steps - 1, (x + y) // 2)]
    return small.resize((W, W), Image.BICUBIC)


def rounded_card(width, height, radius, fill, outline=None, outline_width=0):
    card = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=fill,
                        outline=outline, width=outline_width)
    return card


def paste_rotated(base, layer, center, angle, shadow=True):
    rotated = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    x = int(center[0] - rotated.width / 2)
    y = int(center[1] - rotated.height / 2)
    if shadow:
        alpha = rotated.split()[3]
        sh = Image.new("RGBA", rotated.size, (10, 6, 40, 0))
        sh.putalpha(alpha.point(lambda a: int(a * 0.45)))
        sh = sh.filter(ImageFilter.GaussianBlur(18 * S))
        base.alpha_composite(sh, (x + 6 * S, y + 22 * S))
    base.alpha_composite(rotated, (x, y))


def card_face(width, height, accent):
    """A plain card: white with a coloured art window and two text lines.
    Deliberately generic, not any real card design."""
    r = 34 * S
    card = rounded_card(width, height, r, (250, 249, 255, 255))
    d = ImageDraw.Draw(card)
    m = 30 * S
    # art window
    d.rounded_rectangle((m, m, width - m, int(height * 0.58)), radius=18 * S, fill=accent)
    # text lines
    y1 = int(height * 0.66)
    d.rounded_rectangle((m, y1, width - m, y1 + 22 * S), radius=11 * S, fill=(214, 210, 236, 255))
    y2 = y1 + 46 * S
    d.rounded_rectangle((m, y2, int(width * 0.62), y2 + 22 * S), radius=11 * S, fill=(214, 210, 236, 255))
    return card


def tick_badge(diameter, ring, fill, tick_colour):
    badge = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
    d = ImageDraw.Draw(badge)
    d.ellipse((0, 0, diameter - 1, diameter - 1), fill=ring)
    inset = int(diameter * 0.09)
    d.ellipse((inset, inset, diameter - 1 - inset, diameter - 1 - inset), fill=fill)
    # tick
    w = int(diameter * 0.11)
    p1 = (diameter * 0.29, diameter * 0.53)
    p2 = (diameter * 0.44, diameter * 0.68)
    p3 = (diameter * 0.72, diameter * 0.37)
    d.line([p1, p2, p3], fill=tick_colour, width=w, joint="curve")
    for p in (p1, p3):
        d.ellipse((p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2), fill=tick_colour)
    return badge


def draw(variant):
    if variant == "light":
        bg = gradient((44, 38, 120), (98, 70, 196)).convert("RGBA")
    else:  # dark and tinted share a near-black base
        bg = gradient((16, 14, 34), (34, 28, 70)).convert("RGBA")

    cw, ch = int(W * 0.36), int(W * 0.50)
    cx, cy = W / 2, W * 0.50
    accents = [(255, 190, 70, 255), (120, 200, 255, 255), (150, 110, 255, 255)]
    # back-left, back-right, front
    paste_rotated(bg, card_face(cw, ch, accents[0]), (cx - W * 0.14, cy + W * 0.02), 16)
    paste_rotated(bg, card_face(cw, ch, accents[1]), (cx + W * 0.14, cy + W * 0.02), -16)
    paste_rotated(bg, card_face(cw, ch, accents[2]), (cx, cy - W * 0.02), 0)

    bd = int(W * 0.26)
    badge = tick_badge(bd, (255, 255, 255, 255), (245, 176, 46, 255), (255, 255, 255, 255))
    paste_rotated(bg, badge, (cx + W * 0.19, cy + W * 0.20), 0)

    img = bg.resize((SIZE, SIZE), Image.LANCZOS)
    if variant == "tinted":
        # iOS tints the icon itself; it wants a greyscale image on black.
        img = img.convert("L").convert("RGB")
    return img.convert("RGB")


OUT.mkdir(parents=True, exist_ok=True)
draw("light").save(OUT / "AppIcon.png")
draw("dark").save(OUT / "AppIcon-Dark.png")
draw("tinted").save(OUT / "AppIcon-Tinted.png")
print("written to", OUT)
