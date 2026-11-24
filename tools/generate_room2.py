"""Generates the west ritual storage room, the inscribed corridor that links it
to the main arena, and the animated props those rooms need.

Assets written next to arena_map.png:
  room2_map.png         2300x2100 floor plan (1800x1800-style stone, but colder)
  corridor_map.png       750x500  connecting passage
  corridor_glyphs.png    750x500  pulsing inscription overlay for the corridor
  summon_ring.png        400x400  corner ritual ring
  torch_flame_blue.png   768x160  6-frame blue flame sheet
  water_ripple.png        96x96   expanding ring used by puddle_ripples.gd
"""

from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math
import os
import random

# ---------------------------------------------------------------- constants
PIXEL = 8

ROOM_W, ROOM_H = 2300, 2100
WALL = 100
ROOM_CX, ROOM_CY = ROOM_W // 2, ROOM_H // 2

COR_W, COR_H = 750, 500
COR_CX, COR_CY = COR_W // 2, COR_H // 2

# texture pixel -> world position helpers are only shown in comments; the room
# sprite is placed at (-2700, 0) and the corridor sprite at (-1275, 0).
# room2:  world_x = local_x - 3850, world_y = local_y - 1050
# corridor: world_x = local_x - 1650, world_y = local_y - 250

FLOOR_BASE = (79, 79, 79)
WALL_BASE = (47, 47, 49)
GROUT = (34, 34, 36)

ICE = (142, 184, 232, 228)
PALE = (196, 206, 215, 205)
OCHRE = (190, 160, 118, 200)
IRON = (92, 94, 98, 255)
IRON_DARK = (38, 39, 42, 255)

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")
os.makedirs(OUT_DIR, exist_ok=True)


# ---------------------------------------------------------------- helpers
def shade(c, amt):
    k = random.randint(-amt, amt)
    return tuple(max(0, min(255, int(v + k))) for v in c)


def layer(size=(ROOM_W, ROOM_H)):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def add_glow(base, cx, cy, rx, ry, color, blur=20):
    g = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    gd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color)
    base.alpha_composite(g.filter(ImageFilter.GaussianBlur(blur)))


def px_snap(v):
    return int(round(v / PIXEL) * PIXEL)


def px_block(dr, x0, y0, x1, y1, col):
    x0 = px_snap(x0)
    x1 = max(x0 + PIXEL, px_snap(x1))
    y0 = px_snap(y0)
    y1 = max(y0 + PIXEL, px_snap(y1))
    dr.rectangle([x0, y0, x1 - 1, y1 - 1], fill=col)


def pixelate(base, colors=40):
    small = base.convert("RGB").resize((base.width // PIXEL, base.height // PIXEL), Image.BOX)
    small = small.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    return small.resize(base.size, Image.NEAREST).convert("RGBA")


def pixelate_overlay(overlay):
    small = overlay.resize((overlay.width // PIXEL, overlay.height // PIXEL), Image.BOX)
    return small.resize(overlay.size, Image.NEAREST)


def pixelate_rgba(base):
    """Keeps transparency intact (used for props that sit on the floor)."""
    small = base.resize((base.width // PIXEL, base.height // PIXEL), Image.BOX)
    return small.resize(base.size, Image.NEAREST)


def crack(dr, x, y, steps, angle, width, color=(24, 24, 27, 255), branch=True):
    pts = [(x, y)]
    for _ in range(steps):
        angle += random.uniform(-0.55, 0.55)
        x += math.cos(angle) * random.uniform(8, 24)
        y += math.sin(angle) * random.uniform(8, 24)
        pts.append((x, y))
    dr.line(pts, fill=color, width=width, joint="curve")
    if branch and random.random() < 0.45:
        bx, by = random.choice(pts)
        crack(dr, bx, by, random.randint(2, 4), angle + random.uniform(-1.2, 1.2), 2, branch=False)


def glyph(dr, cx, cy, s, kind, color, w=6):
    """Same pictogram vocabulary as the main arena carvings."""
    h = s / 2.0
    if kind == 0:  # ankh
        dr.ellipse([cx - h * 0.5, cy - h, cx + h * 0.5, cy - h * 0.1], outline=color, width=w)
        dr.line([cx, cy - h * 0.1, cx, cy + h], fill=color, width=w)
        dr.line([cx - h * 0.65, cy + h * 0.3, cx + h * 0.65, cy + h * 0.3], fill=color, width=w)
    elif kind == 1:  # sun disk
        dr.ellipse([cx - h * 0.7, cy - h * 0.7, cx + h * 0.7, cy + h * 0.7], outline=color, width=w)
        dr.ellipse([cx - h * 0.15, cy - h * 0.15, cx + h * 0.15, cy + h * 0.15], fill=color)
    elif kind == 2:  # water
        pts = [(cx - h + i * h * 0.5, cy + (h * 0.35 if i % 2 == 0 else -h * 0.35)) for i in range(5)]
        dr.line(pts, fill=color, width=w, joint="curve")
    elif kind == 3:  # triangle
        pts = [(cx, cy - h), (cx + h * 0.8, cy + h * 0.7), (cx - h * 0.8, cy + h * 0.7)]
        dr.line(pts + [pts[0]], fill=color, width=w, joint="curve")
    elif kind == 4:  # bars
        for i in (-1, 0, 1):
            dr.line([cx + i * h * 0.5, cy - h * 0.8, cx + i * h * 0.5, cy + h * 0.8], fill=color, width=w)
    elif kind == 5:  # diamond
        pts = [(cx, cy - h), (cx + h * 0.7, cy), (cx, cy + h), (cx - h * 0.7, cy)]
        dr.line(pts + [pts[0]], fill=color, width=w, joint="curve")
    elif kind == 6:  # hook
        dr.line([cx, cy - h, cx, cy + h * 0.3], fill=color, width=w)
        dr.arc([cx - h * 0.6, cy - h * 0.1, cx + h * 0.6, cy + h * 0.9], 0, 180, fill=color, width=w)
    elif kind == 7:  # double dot
        dr.ellipse([cx - h * 0.55, cy - h * 0.35, cx - h * 0.05, cy + h * 0.15], outline=color, width=w)
        dr.ellipse([cx + h * 0.05, cy - h * 0.15, cx + h * 0.55, cy + h * 0.35], outline=color, width=w)
    elif kind == 8:  # arrow
        dr.line([cx, cy + h, cx, cy - h], fill=color, width=w)
        dr.line([cx, cy - h, cx - h * 0.5, cy - h * 0.4], fill=color, width=w)
        dr.line([cx, cy - h, cx + h * 0.5, cy - h * 0.4], fill=color, width=w)
    else:  # nested squares
        dr.rectangle([cx - h * 0.7, cy - h * 0.7, cx + h * 0.7, cy + h * 0.7], outline=color, width=w)
        dr.rectangle([cx - h * 0.3, cy - h * 0.3, cx + h * 0.3, cy + h * 0.3], outline=color, width=w)


def skull_tile(size, tint=(184, 198, 212), aged=False):
    s = int(size)
    t = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(t)
    sd.ellipse([s * 0.14, s * 0.10, s * 0.86, s * 0.66], fill=tint + (255,))
    sd.rounded_rectangle([s * 0.27, s * 0.46, s * 0.73, s * 0.86], radius=int(s * 0.13), fill=tint + (255,))
    dark = (26, 28, 34, 255)
    sd.ellipse([s * 0.22, s * 0.28, s * 0.45, s * 0.50], fill=dark)
    sd.ellipse([s * 0.55, s * 0.28, s * 0.78, s * 0.50], fill=dark)
    sd.polygon([(s * 0.5, s * 0.46), (s * 0.43, s * 0.60), (s * 0.57, s * 0.60)], fill=dark)
    for i in range(4):
        xx = s * 0.34 + i * s * 0.09
        sd.line([(xx, s * 0.65), (xx, s * 0.80)], fill=(66, 74, 84, 255), width=max(1, int(s * 0.025)))
    sd.arc([s * 0.14, s * 0.10, s * 0.86, s * 0.66], 200, 340, fill=(132, 146, 160, 255), width=max(1, int(s * 0.02)))
    sd.ellipse([s * 0.30, s * 0.16, s * 0.46, s * 0.28], fill=(232, 244, 255, 90))
    if aged:
        for _ in range(9):
            ox = random.uniform(0.16, 0.84) * s
            oy = random.uniform(0.12, 0.82) * s
            rr = random.uniform(0.05, 0.13) * s
            sd.ellipse([ox - rr, oy - rr * 0.8, ox + rr, oy + rr * 0.8], fill=(48, 54, 62, 60))
        pts = [(s * 0.46, s * 0.12), (s * 0.54, s * 0.26), (s * 0.46, s * 0.38), (s * 0.53, s * 0.52)]
        sd.line(pts, fill=(64, 70, 78, 210), width=max(1, int(s * 0.022)))
        alpha = t.getchannel("A")
        ad2 = ImageDraw.Draw(alpha)
        for _ in range(5):
            ox = random.choice([random.uniform(0.05, 0.18), random.uniform(0.82, 0.95)]) * s
            oy = random.uniform(0.18, 0.62) * s
            rr = random.uniform(0.03, 0.07) * s
            ad2.ellipse([ox - rr, oy - rr, ox + rr, oy + rr], fill=0)
        t.putalpha(alpha)
    return t


# =================================================================== ROOM 2
random.seed(71)
img = Image.new("RGBA", (ROOM_W, ROOM_H), (6, 7, 9, 255))
d = ImageDraw.Draw(img)

# ------------------------------------------------------------------ floor
d.rectangle([WALL, WALL, ROOM_W - WALL - 1, ROOM_H - WALL - 1], fill=GROUT + (255,))
TILE = 154
row = 0
y = WALL
while y < ROOM_H - WALL:
    offset = 0 if row % 2 == 0 else TILE // 2
    x = WALL - offset
    y2 = min(y + TILE - 4, ROOM_H - WALL - 1)
    while x < ROOM_W - WALL:
        x1 = max(WALL, x + 3)
        x2 = min(x + TILE - 4, ROOM_W - WALL - 1)
        if x2 - x1 > 24:
            d.rectangle([x1, y + 3, x2, y2], fill=shade(FLOOR_BASE, 6) + (255,))
        x += TILE
    y += TILE
    row += 1

pits = layer()
pdd = ImageDraw.Draw(pits)
for _ in range(1150):
    px = random.uniform(WALL + 6, ROOM_W - WALL - 6)
    py = random.uniform(WALL + 6, ROOM_H - WALL - 6)
    pr = random.uniform(0.7, 2.6)
    pdd.ellipse([px - pr, py - pr, px + pr, py + pr],
                fill=(24, 25, 28, random.randint(40, 90)))
    if random.random() < 0.35:
        pdd.ellipse([px - pr * 1.8 - 1, py - pr * 1.8 - 1, px - pr * 1.8 + 1, py - pr * 1.8 + 1],
                    fill=(112, 116, 122, 55))
for _ in range(190):
    px = random.uniform(WALL + 10, ROOM_W - WALL - 10)
    py = random.uniform(WALL + 10, ROOM_H - WALL - 10)
    pr = random.uniform(2, 5)
    pdd.ellipse([px - pr, py - pr * 0.7, px + pr, py + pr * 0.7],
                fill=(118, 124, 130, 35))
img.alpha_composite(pits)

ao = layer()
ad = ImageDraw.Draw(ao)
for i in range(30):
    a = max(0, 115 - i * 4)
    ad.rectangle([WALL + i, WALL + i, ROOM_W - WALL - 1 - i, ROOM_H - WALL - 1 - i],
                 outline=(0, 0, 0, a), width=1)
img.alpha_composite(ao.filter(ImageFilter.GaussianBlur(12)))

for _ in range(2):
    n = Image.effect_noise((ROOM_W, ROOM_H), 22).convert("L")
    img.alpha_composite(Image.merge("RGBA", (n, n, n, Image.new("L", (ROOM_W, ROOM_H), 11))))

# --------------------------------------------------------- cold damp stains
damp = layer()
dpd = ImageDraw.Draw(damp)
for cx, cy, rx, ry in [
    (760, 760, 210, 160), (1410, 620, 190, 140), (1660, 1120, 220, 180),
    (1010, 1390, 200, 160), (1470, 1580, 210, 150), (650, 1640, 180, 140),
    (1120, 980, 260, 200), (300, 900, 170, 190), (980, 300, 190, 140),
]:
    dpd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(28, 43, 56, 44))
img.alpha_composite(damp.filter(ImageFilter.GaussianBlur(26)))

# ------------------------------------------------------------ glyph band
glyph_layer = layer()
gd = ImageDraw.Draw(glyph_layer)
deco_layer = layer()
dd = ImageDraw.Draw(deco_layer)

INSET = 156
BAND = 94
MID = INSET + BAND / 2
STEP = 120
idx = 0
x = INSET + 70
while x <= ROOM_W - INSET - 70:
    glyph(gd, x, MID, 58, idx % 10, OCHRE if idx % 4 else PALE, 6)
    idx += 1
    x += STEP
x = INSET + 70
while x <= ROOM_W - INSET - 70:
    glyph(gd, x, ROOM_H - MID, 58, idx % 10, ICE if idx % 3 else OCHRE, 6)
    idx += 1
    x += STEP
y = INSET + 70
while y <= ROOM_H - INSET - 70:
    glyph(gd, MID, y, 58, idx % 10, ICE if idx % 3 else OCHRE, 6)
    glyph(gd, ROOM_W - MID, y, 58, idx % 10, OCHRE if idx % 4 else PALE, 6)
    idx += 2
    y += STEP

dd.rectangle([INSET, INSET, ROOM_W - INSET, ROOM_H - INSET], outline=(118, 146, 176, 90), width=4)
dd.rectangle([INSET + BAND, INSET + BAND, ROOM_W - INSET - BAND, ROOM_H - INSET - BAND],
             outline=(110, 140, 170, 66), width=3)

# large, half-erased ritual sigil under the room's clutter
SIG = (126, 170, 214, 62)
dd.arc([ROOM_CX - 430, ROOM_CY - 430, ROOM_CX + 430, ROOM_CY + 430], 18, 150, fill=SIG, width=6)
dd.arc([ROOM_CX - 430, ROOM_CY - 430, ROOM_CX + 430, ROOM_CY + 430], 196, 336, fill=SIG, width=6)
dd.arc([ROOM_CX - 350, ROOM_CY - 350, ROOM_CX + 350, ROOM_CY + 350], 64, 210, fill=(110, 152, 196, 45), width=3)
dd.arc([ROOM_CX - 350, ROOM_CY - 350, ROOM_CX + 350, ROOM_CY + 350], 240, 350, fill=(110, 152, 196, 45), width=3)
for k in range(4):
    a = math.pi / 2 * k + math.pi / 4
    dd.line([ROOM_CX + math.cos(a) * 120, ROOM_CY + math.sin(a) * 120,
             ROOM_CX + math.cos(a) * 430, ROOM_CY + math.sin(a) * 430], fill=(104, 142, 184, 46), width=3)
dd.ellipse([ROOM_CX - 58, ROOM_CY - 58, ROOM_CX + 58, ROOM_CY + 58], outline=(134, 176, 218, 82), width=4)
dd.ellipse([ROOM_CX - 18, ROOM_CY - 18, ROOM_CX + 18, ROOM_CY + 18], outline=(150, 190, 230, 95), width=3)

# wear on the carvings
noise = Image.effect_noise((ROOM_W, ROOM_H), 82).convert("L")
mask = noise.point(lambda v: 0 if v < 68 else 255)
md = ImageDraw.Draw(mask)
for _ in range(230):
    x0 = random.uniform(INSET, ROOM_W - INSET)
    y0 = random.uniform(INSET, ROOM_H - INSET)
    ang = random.uniform(0, math.tau)
    ln = random.uniform(20, 160)
    md.line([x0, y0, x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln],
            fill=0, width=random.randint(1, 4))
r, g, b, a = glyph_layer.split()
glyph_layer.putalpha(ImageChops.multiply(a, mask))

glyph_overlay = layer()
for blur, strength in ((20, 0.52), (8, 0.40)):
    glow_a = glyph_layer.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
    glow_a = glow_a.point(lambda v: int(v * strength))
    blue_glow = Image.new("RGBA", (ROOM_W, ROOM_H), (74, 138, 236, 255))
    blue_glow.putalpha(glow_a)
    glyph_overlay.alpha_composite(blue_glow)
glyph_overlay.alpha_composite(glyph_layer)

img.alpha_composite(damp.filter(ImageFilter.GaussianBlur(30)))
img.alpha_composite(deco_layer)
img.alpha_composite(glyph_overlay)

# cold light spilling in through the east gate
gate_glow = layer()
ggd = ImageDraw.Draw(gate_glow)
ggd.ellipse([ROOM_W - 430, ROOM_CY - 230, ROOM_W - 40, ROOM_CY + 230], fill=(54, 120, 200, 62))
img.alpha_composite(gate_glow.filter(ImageFilter.GaussianBlur(38)))

# --------------------------------------------------------------- cracks
crack_layer = layer()
cd = ImageDraw.Draw(crack_layer)
for _ in range(26):
    crack(cd, random.uniform(WALL + 30, ROOM_W - WALL - 30),
          random.uniform(WALL + 30, ROOM_H - WALL - 30),
          random.randint(6, 14), random.uniform(0, math.tau), random.randint(2, 3))
for _ in range(210):
    x0 = random.uniform(WALL + 20, ROOM_W - WALL - 20)
    y0 = random.uniform(WALL + 20, ROOM_H - WALL - 20)
    ang = random.uniform(0, math.tau)
    ln = random.uniform(30, 180)
    col = (132, 136, 142, random.randint(40, 90)) if random.random() < 0.75 else (22, 23, 26, 85)
    cd.line([x0, y0, x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln],
            fill=col, width=random.choice([1, 1, 2]))
    if random.random() < 0.2:
        for k in range(3):
            off = (k - 1) * 9
            ox = math.cos(ang + 1.57) * off
            oy = math.sin(ang + 1.57) * off
            cd.line([x0 + ox, y0 + oy, x0 + ox + math.cos(ang) * ln, y0 + oy + math.sin(ang) * ln],
                    fill=col, width=1)
img.alpha_composite(crack_layer)


# --------------------------------------------------------------- puddles
PUDDLES = [
    (760, 760, 74, 42), (1410, 620, 62, 36), (1680, 820, 82, 48),
    (1010, 1390, 70, 40), (1470, 1580, 78, 44), (650, 1640, 58, 34),
    (1120, 980, 96, 54),
]


def draw_puddle(cx, cy, rx, ry):
    n = random.randint(11, 15)
    pts = []
    for i in range(n):
        ang = math.tau * i / n
        rr = random.uniform(0.72, 1.0)
        pts.append((cx + math.cos(ang) * rx * rr, cy + math.sin(ang) * ry * rr))
    # damp halo
    halo = layer()
    hd2 = ImageDraw.Draw(halo)
    hd2.ellipse([cx - rx * 1.25, cy - ry * 1.3, cx + rx * 1.25, cy + ry * 1.3], fill=(26, 44, 60, 70))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(10)))
    d.polygon(pts, fill=(27, 40, 52, 185))
    d.line(pts + [pts[0]], fill=(58, 78, 92, 150), width=3, joint="curve")
    # sky / torch reflection
    d.ellipse([cx - rx * 0.52, cy - ry * 0.48, cx + rx * 0.18, cy + ry * 0.05], fill=(40, 62, 82, 120))
    d.line([cx - rx * 0.44, cy - ry * 0.20, cx + rx * 0.10, cy + ry * 0.10], fill=(92, 132, 158, 120), width=3)
    for _ in range(random.randint(3, 6)):
        gx = cx + random.uniform(-rx * 0.7, rx * 0.7)
        gy = cy + random.uniform(-ry * 0.6, ry * 0.6)
        gr = random.uniform(1.5, 3.5)
        d.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=(112, 152, 176, 95))


for p in PUDDLES:
    draw_puddle(*p)

# ---------------------------------------------------------- steel grates
def draw_grate(x0, y0, w, h):
    d.rectangle([x0, y0, x0 + w, y0 + h], fill=(20, 22, 25, 255))
    # wet channel under the bars
    d.rectangle([x0 + 10, y0 + 10, x0 + w - 10, y0 + h - 10], fill=(15, 30, 40, 255))
    for _ in range(14):
        gx = random.uniform(x0 + 14, x0 + w - 14)
        gy = random.uniform(y0 + 14, y0 + h - 14)
        gr = random.uniform(1, 3)
        d.ellipse([gx - gr, gy - gr, gx + gr, gy + gr], fill=(44, 74, 88, 130))
    # stone / iron frame
    d.rectangle([x0, y0, x0 + w, y0 + h], outline=(72, 72, 74, 255), width=6)
    d.rectangle([x0 + 5, y0 + 5, x0 + w - 5, y0 + h - 5], outline=(26, 27, 29, 255), width=3)
    bars = max(4, int(w / 30))
    for i in range(1, bars):
        bx = x0 + (w / bars) * i
        d.rectangle([bx - 3, y0 + 12, bx + 3, y0 + h - 12], fill=(64, 66, 70, 255))
        d.line([bx - 2, y0 + 14, bx - 2, y0 + h - 14], fill=(104, 106, 110, 255), width=1)
    d.rectangle([x0 + 12, y0 + h * 0.5 - 4, x0 + w - 12, y0 + h * 0.5 + 4], fill=(58, 60, 64, 255))
    for bx in (x0 + 6, x0 + w - 6):
        for by in (y0 + 6, y0 + h - 6):
            d.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(118, 120, 124, 255))
    # cold glint on the near edge
    d.line([x0 + 8, y0 + 3, x0 + w - 8, y0 + 3], fill=(128, 142, 150, 190), width=2)


for gx, gy, gw, gh in [
    (900, 1650, 300, 140), (1400, 320, 260, 130),
    (560, 600, 220, 120), (1550, 1200, 260, 130),
]:
    draw_grate(gx, gy, gw, gh)

# ------------------------------------------------------------- storage props
prop_shadow = layer()
psd = ImageDraw.Draw(prop_shadow)


def crate_tile(size, tone=(196, 150, 90)):
    s = int(size)
    t = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    cr = ImageDraw.Draw(t)
    pad = int(s * 0.05)
    edge = (68, 46, 25, 255)
    light = (246, 214, 160, 255)
    dark = (120, 86, 48, 255)
    cr.rectangle([pad, pad, s - pad, s - pad], fill=tone + (255,), outline=edge, width=max(4, int(s * 0.05)))
    # vertical planks with alternating grain
    for i in range(4):
        x0 = pad + (s - pad * 2) * i / 4
        x1 = pad + (s - pad * 2) * (i + 1) / 4
        plank = (214, 166, 104) if i % 2 == 0 else (180, 136, 82)
        cr.rectangle([x0 + 3, pad + 4, x1 - 3, s - pad - 4], fill=plank + (255,))
        cr.line([x0 + 5, pad + 6, x0 + 5, s - pad - 6], fill=light, width=2)
        cr.line([x1 - 5, pad + 6, x1 - 5, s - pad - 6], fill=edge, width=2)
    # cross braces
    brace = (124, 88, 48, 255)
    cr.line([pad + 7, pad + 7, s - pad - 7, s - pad - 7], fill=brace, width=max(4, int(s * 0.05)))
    cr.line([s - pad - 7, pad + 7, pad + 7, s - pad - 7], fill=brace, width=max(4, int(s * 0.05)))
    cr.line([pad + 7, pad + 7, s - pad - 7, pad + 7], fill=light, width=3)
    cr.line([pad + 7, pad + 7, pad + 7, s - pad - 7], fill=(232, 190, 132, 255), width=3)
    # iron corner brackets
    b = max(10, int(s * 0.17))
    for bx, by in ((pad, pad), (s - pad - b, pad), (pad, s - pad - b), (s - pad - b, s - pad - b)):
        cr.rectangle([bx, by, bx + b, by + b], fill=(174, 176, 180, 255), outline=(36, 37, 40, 255), width=3)
        cr.line([bx + 2, by + 2, bx + b - 3, by + 2], fill=(232, 234, 238, 255), width=2)
    for bx, by in ((pad + b * 0.5, pad + b * 0.5), (s - pad - b * 0.5, pad + b * 0.5),
                   (pad + b * 0.5, s - pad - b * 0.5), (s - pad - b * 0.5, s - pad - b * 0.5)):
        cr.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(214, 216, 220, 255))
    return t


def barrel_tile(radius):
    s = int(radius * 2 + 10)
    t = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    br = ImageDraw.Draw(t)
    c = s / 2
    r = radius
    br.ellipse([c - r, c - r, c + r, c + r], fill=(196, 146, 86, 255))
    br.ellipse([c - r, c - r, c + r, c + r], outline=(62, 43, 25, 255), width=6)
    # radial staves, alternating tones so the barrel reads from the top
    for k in range(12):
        a = math.tau * k / 12
        col = (216, 162, 98, 230) if k % 2 == 0 else (166, 120, 70, 230)
        br.line([c + math.cos(a) * r * 0.20, c + math.sin(a) * r * 0.20,
                 c + math.cos(a) * r * 0.93, c + math.sin(a) * r * 0.93],
                fill=col, width=3)
    for rr, width in ((r * 0.90, 6), (r * 0.58, 5), (r * 0.22, 4)):
        br.ellipse([c - rr, c - rr, c + rr, c + rr], outline=(150, 152, 158, 255), width=width)
        br.arc([c - rr, c - rr, c + rr, c + rr], 195, 320, fill=(190, 192, 196, 255), width=2)
    br.ellipse([c - r * 0.18, c - r * 0.18, c + r * 0.18, c + r * 0.18], fill=(150, 106, 62, 255))
    br.ellipse([c - r * 0.10, c - r * 0.10, c + r * 0.10, c + r * 0.10], fill=(92, 64, 36, 255))
    br.arc([c - r * 0.72, c - r * 0.72, c + r * 0.72, c + r * 0.72], 190, 300, fill=(250, 208, 150, 180), width=2)
    return t


def paste_prop(tile, cx, cy, angle=0.0, shadow_rx=None, shadow_ry=None):
    if shadow_rx is None:
        shadow_rx = tile.width * 0.42
    if shadow_ry is None:
        shadow_ry = tile.height * 0.30
    psd.ellipse([cx - shadow_rx + 4, cy - shadow_ry + 6, cx + shadow_rx + 4, cy + shadow_ry + 6],
                fill=(0, 0, 0, 105))
    t = tile.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(t, (int(cx - t.width / 2), int(cy - t.height / 2)))


for cx, cy, sz, ang in [
    (260, 880, 84, -8), (430, 1030, 72, 11), (250, 1200, 80, 5), (420, 1360, 66, -14),
    (940, 280, 88, 7), (1130, 400, 72, -10), (1770, 1240, 82, 12), (1620, 1420, 70, -6),
]:
    paste_prop(crate_tile(sz), cx, cy, ang)

for cx, cy, rr in [
    (366, 1082, 42), (526, 882, 38), (1024, 432, 40), (1810, 1182, 44), (1734, 1452, 36),
]:
    paste_prop(barrel_tile(rr), cx, cy, 0.0, rr * 1.05, rr * 0.9)

img.alpha_composite(prop_shadow.filter(ImageFilter.GaussianBlur(6)))

# ------------------------------------------------------------------ walls
d.rectangle([0, 0, ROOM_W - 1, WALL - 1], fill=WALL_BASE + (255,))
d.rectangle([0, ROOM_H - WALL, ROOM_W - 1, ROOM_H - 1], fill=WALL_BASE + (255,))
d.rectangle([0, 0, WALL - 1, ROOM_H - 1], fill=WALL_BASE + (255,))
d.rectangle([ROOM_W - WALL, 0, ROOM_W - 1, ROOM_H - 1], fill=WALL_BASE + (255,))

BL = 142
for x in range(0, ROOM_W, BL):
    d.rectangle([x + 3, 3, min(x + BL - 4, ROOM_W - 1), WALL - 4], fill=shade((56, 56, 58), 5) + (255,))
    d.rectangle([x + 3, ROOM_H - WALL + 3, min(x + BL - 4, ROOM_W - 1), ROOM_H - 4], fill=shade((54, 54, 56), 5) + (255,))
for yy in range(WALL, ROOM_H - WALL, BL):
    d.rectangle([3, yy + 3, WALL - 4, min(yy + BL - 4, ROOM_H - WALL - 1)], fill=shade((55, 55, 57), 5) + (255,))
    d.rectangle([ROOM_W - WALL + 3, yy + 3, ROOM_W - 4, min(yy + BL - 4, ROOM_H - WALL - 1)], fill=shade((55, 55, 57), 5) + (255,))

crack_layer2 = layer()
c2 = ImageDraw.Draw(crack_layer2)
for _ in range(20):
    side = random.randint(0, 3)
    if side == 0:
        crack(c2, random.uniform(0, ROOM_W), random.uniform(6, WALL - 6), random.randint(4, 9), random.uniform(0, math.tau), 2)
    elif side == 1:
        crack(c2, random.uniform(0, ROOM_W), random.uniform(ROOM_H - WALL + 6, ROOM_H - 6), random.randint(4, 9), random.uniform(0, math.tau), 2)
    elif side == 2:
        crack(c2, random.uniform(6, WALL - 6), random.uniform(0, ROOM_H), random.randint(4, 9), random.uniform(0, math.tau), 2)
    else:
        crack(c2, random.uniform(ROOM_W - WALL + 6, ROOM_W - 6), random.uniform(0, ROOM_H), random.randint(4, 9), random.uniform(0, math.tau), 2)
img.alpha_composite(crack_layer2)

# raised walls: inner face, seams, bevel, shadow
FACE = 38
d.rectangle([WALL, WALL - FACE, ROOM_W - WALL - 1, WALL - 1], fill=(35, 36, 39, 255))
d.rectangle([WALL, ROOM_H - WALL, ROOM_W - WALL - 1, ROOM_H - WALL + FACE - 1], fill=(35, 36, 39, 255))
d.rectangle([WALL - FACE, WALL, WALL - 1, ROOM_H - WALL - 1], fill=(35, 36, 39, 255))
d.rectangle([ROOM_W - WALL, WALL, ROOM_W - WALL + FACE - 1, ROOM_H - WALL - 1], fill=(35, 36, 39, 255))

for x in range(0, ROOM_W, BL):
    d.line([x + 3, WALL - FACE, x + 3, WALL - 1], fill=(23, 24, 26, 255), width=2)
    d.line([x + 3, ROOM_H - WALL, x + 3, ROOM_H - WALL + FACE - 1], fill=(23, 24, 26, 255), width=2)
for yy in range(0, ROOM_H, BL):
    d.line([WALL - FACE, yy + 3, WALL - 1, yy + 3], fill=(23, 24, 26, 255), width=2)
    d.line([ROOM_W - WALL, yy + 3, ROOM_W - WALL + FACE - 1, yy + 3], fill=(23, 24, 26, 255), width=2)

d.line([0, WALL - FACE - 2, ROOM_W - 1, WALL - FACE - 2], fill=(116, 118, 124, 255), width=4)
d.line([0, ROOM_H - WALL + FACE + 1, ROOM_W - 1, ROOM_H - WALL + FACE + 1], fill=(116, 118, 124, 255), width=4)
d.line([WALL - FACE - 2, 0, WALL - FACE - 2, ROOM_H - 1], fill=(116, 118, 124, 255), width=4)
d.line([ROOM_W - WALL + FACE + 1, 0, ROOM_W - WALL + FACE + 1, ROOM_H - 1], fill=(116, 118, 124, 255), width=4)

raise_sh = layer()
rsd = ImageDraw.Draw(raise_sh)
for i in range(80):
    a = int(180 * (1 - i / 80) ** 1.45)
    rsd.rectangle([WALL + i, WALL + i, ROOM_W - WALL - 1 - i, ROOM_H - WALL - 1 - i],
                  outline=(0, 0, 0, a), width=1)
img.alpha_composite(raise_sh.filter(ImageFilter.GaussianBlur(10)))

d.line([WALL, WALL, ROOM_W - WALL - 1, WALL], fill=(14, 15, 17, 255), width=3)
d.line([WALL, ROOM_H - WALL - 1, ROOM_W - WALL - 1, ROOM_H - WALL - 1], fill=(14, 15, 17, 255), width=3)
d.line([WALL, WALL, WALL, ROOM_H - WALL - 1], fill=(14, 15, 17, 255), width=3)
d.line([ROOM_W - WALL - 1, WALL, ROOM_W - WALL - 1, ROOM_H - WALL - 1], fill=(14, 15, 17, 255), width=3)

d.rectangle([0, 0, ROOM_W - 1, ROOM_H - 1], outline=(14, 15, 17, 255), width=6)
d.rectangle([2, 2, ROOM_W - 3, ROOM_H - 3], outline=(84, 86, 92, 255), width=2)

# ----------------------------------------------------- east gate to corridor
GATE_Y0, GATE_Y1 = 900, 1200
d.rectangle([ROOM_W - WALL, GATE_Y0, ROOM_W - 1, GATE_Y1 - 1], fill=(31, 33, 37, 255))
for gy in range(GATE_Y0, GATE_Y1, 72):
    d.line([ROOM_W - WALL + 2, gy, ROOM_W - 2, gy], fill=(22, 24, 28, 255), width=2)
d.line([ROOM_W - WALL // 2, GATE_Y0, ROOM_W - WALL // 2, GATE_Y1], fill=(22, 24, 28, 255), width=2)
# jambs
d.rectangle([ROOM_W - WALL, GATE_Y0 - 48, ROOM_W - 1, GATE_Y0 - 1], fill=(92, 92, 96, 255))
d.rectangle([ROOM_W - WALL, GATE_Y1, ROOM_W - 1, GATE_Y1 + 47], fill=(92, 92, 96, 255))
d.rectangle([ROOM_W - WALL, GATE_Y0 - 48, ROOM_W - 1, GATE_Y0 - 1], outline=(38, 39, 42, 255), width=2)
d.rectangle([ROOM_W - WALL, GATE_Y1, ROOM_W - 1, GATE_Y1 + 47], outline=(38, 39, 42, 255), width=2)
# threshold on the room side
d.rectangle([ROOM_W - WALL - 10, GATE_Y0 - 4, ROOM_W - WALL + 10, GATE_Y1 + 3], fill=(66, 67, 71, 255))
d.line([ROOM_W - WALL - 10, GATE_Y0, ROOM_W - WALL - 10, GATE_Y1 - 1], fill=(124, 126, 132, 255), width=2)

# ------------------------------------------------------- torch wall niches
NICHES = [
    # cx, wall side (north/south)
    (600, "north"), (1700, "north"),
    (600, "south"), (1700, "south"),
]


def draw_niche(cx, side):
    if side == "north":
        y0, y1 = 14, WALL - 1
        open_y = WALL - 1
    else:
        y0, y1 = ROOM_H - WALL, ROOM_H - 15
        open_y = ROOM_H - WALL
    niche_w = 270
    # recess
    d.rectangle([cx - niche_w / 2, y0, cx + niche_w / 2, y1], fill=(13, 14, 18, 255))
    # stone lip around the opening
    d.rectangle([cx - niche_w / 2 - 12, y0 - 8, cx + niche_w / 2 + 12, y0], fill=(78, 79, 84, 255))
    d.rectangle([cx - niche_w / 2 - 12, y0 - 8, cx + niche_w / 2 + 12, y0], outline=(32, 33, 36, 255), width=2)
    d.rectangle([cx - niche_w / 2 - 12, y0, cx - niche_w / 2, y1], fill=(84, 85, 90, 255))
    d.rectangle([cx + niche_w / 2, y0, cx + niche_w / 2 + 12, y1], fill=(84, 85, 90, 255))
    d.line([cx - niche_w / 2 + 3, y0 + 3, cx - niche_w / 2 + 3, y1 - 3], fill=(116, 118, 124, 255), width=2)
    d.line([cx + niche_w / 2 - 3, y0 + 3, cx + niche_w / 2 - 3, y1 - 3], fill=(38, 39, 42, 255), width=2)
    # cold fire stains on the recess back
    for _ in range(7):
        ox = random.uniform(-niche_w * 0.32, niche_w * 0.32)
        oy = random.uniform(y0 + 4, y1 - 4) if side == "north" else random.uniform(y0 + 4, y1 - 4)
        rr = random.uniform(6, 18)
        d.ellipse([cx + ox - rr, oy - rr, cx + ox + rr, oy + rr], fill=(30, 52, 82, 90))
    # two chains hang from the compartment ceiling and take the skull by the sides,
    # framing the flame so the mounting stays readable in game
    skull_cy = 64 if side == "north" else ROOM_H - 64
    if side == "north":
        anchor_y = y0 + 5
        attach_y = skull_cy - 8
    else:
        anchor_y = y1 - 5
        attach_y = skull_cy + 8
    for sx in (-1, 1):
        ax = cx + sx * 72
        bx = cx + sx * 28
        for i in range(9):
            t0 = i / 9.0
            t1 = (i + 0.62) / 9.0
            p0 = (ax + (bx - ax) * t0, anchor_y + (attach_y - anchor_y) * t0)
            p1 = (ax + (bx - ax) * t1, anchor_y + (attach_y - anchor_y) * t1)
            d.line([p0, p1], fill=(58, 64, 78, 255), width=7)
            d.line([p0, p1], fill=(164, 176, 194, 255), width=4)
        d.ellipse([ax - 8, anchor_y - 8, ax + 8, anchor_y + 8], outline=(58, 64, 78, 255), width=4)
        d.ellipse([ax - 4, anchor_y - 4, ax + 4, anchor_y + 4], outline=(164, 176, 194, 255), width=2)
    # skull
    sk = skull_tile(78, tint=(178, 194, 210), aged=True)
    img.alpha_composite(sk, (int(cx - sk.width / 2), int(skull_cy - sk.height / 2)))
    # cold bloom on the bone and wall
    add_glow(img, cx, skull_cy, 62, 54, (56, 128, 232, 82), 16)
    add_glow(img, cx, open_y, 96, 52, (40, 112, 210, 58), 22)
    # blue eye sockets
    d.ellipse([cx - 20, skull_cy - 13, cx - 5, skull_cy + 1], fill=(76, 168, 255, 230))
    d.ellipse([cx + 5, skull_cy - 13, cx + 20, skull_cy + 1], fill=(76, 168, 255, 230))
    d.ellipse([cx - 15, skull_cy - 10, cx - 9, skull_cy - 4], fill=(214, 244, 255, 250))
    d.ellipse([cx + 9, skull_cy - 10, cx + 15, skull_cy - 4], fill=(214, 244, 255, 250))


for nx, nside in NICHES:
    draw_niche(nx, nside)

# --------------------------------------------------------------- vignette
vig = Image.new("L", (ROOM_W, ROOM_H), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([-360, -360, ROOM_W + 360, ROOM_H + 360], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(260))
dark = Image.new("RGBA", (ROOM_W, ROOM_H), (0, 2, 8, 84))
dark.putalpha(ImageChops.subtract(Image.new("L", (ROOM_W, ROOM_H), 84), vig))
img.alpha_composite(dark)

# ---------------------------------------------------------- pixel-art pass
glyph_overlay.putalpha(ImageChops.multiply(
    glyph_overlay.getchannel("A"), ImageChops.invert(dark.getchannel("A"))))
img = pixelate(img, 40)

# crisp blue torch eyes on top of the pixel pass
d = ImageDraw.Draw(img)
for nx, nside in NICHES:
    cy = 64 if nside == "north" else ROOM_H - 64
    for ex in (nx - 14, nx + 14):
        px_block(d, ex - 7, cy - 10, ex + 7, cy + 1, (76, 168, 255, 255))
        px_block(d, ex - 3, cy - 7, ex + 3, cy - 2, (214, 244, 255, 255))

room_path = os.path.join(OUT_DIR, "room2_map.png")
img.convert("RGB").save(room_path)

# ================================================================ CORRIDOR
random.seed(72)
cimg = Image.new("RGBA", (COR_W, COR_H), (6, 7, 9, 255))
cd = ImageDraw.Draw(cimg)
c_glyph = layer((COR_W, COR_H))
cgd = ImageDraw.Draw(c_glyph)
c_deco = layer((COR_W, COR_H))
cdd = ImageDraw.Draw(c_deco)

cd.rectangle([0, WALL, COR_W - 1, COR_H - WALL - 1], fill=GROUT + (255,))
CTILE = 130
crow = 0
cy0 = WALL
while cy0 < COR_H - WALL:
    off = 0 if crow % 2 == 0 else CTILE // 2
    cx0 = -off
    y2 = min(cy0 + CTILE - 4, COR_H - WALL - 1)
    while cx0 < COR_W:
        x1 = max(0, cx0 + 3)
        x2 = min(cx0 + CTILE - 4, COR_W - 1)
        if x2 - x1 > 20:
            cd.rectangle([x1, cy0 + 3, x2, y2], fill=shade(FLOOR_BASE, 7) + (255,))
        cx0 += CTILE
    cy0 += CTILE
    crow += 1

# floor pits and damp
for _ in range(320):
    px = random.uniform(2, COR_W - 2)
    py = random.uniform(WALL + 4, COR_H - WALL - 4)
    pr = random.uniform(0.7, 2.4)
    cd.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(24, 25, 28, random.randint(40, 90)))
for _ in range(2):
    n = Image.effect_noise((COR_W, COR_H), 22).convert("L")
    cimg.alpha_composite(Image.merge("RGBA", (n, n, n, Image.new("L", (COR_W, COR_H), 11))))

# corridor puddles
def draw_corridor_puddle(cx, cy, rx, ry):
    halo = layer((COR_W, COR_H))
    hd2 = ImageDraw.Draw(halo)
    hd2.ellipse([cx - rx * 1.3, cy - ry * 1.3, cx + rx * 1.3, cy + ry * 1.3], fill=(26, 44, 60, 70))
    cimg.alpha_composite(halo.filter(ImageFilter.GaussianBlur(8)))
    pts = []
    n = 12
    for i in range(n):
        a = math.tau * i / n
        rr = random.uniform(0.7, 1.0)
        pts.append((cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr))
    cd.polygon(pts, fill=(27, 40, 52, 190))
    cd.line(pts + [pts[0]], fill=(58, 78, 92, 150), width=3, joint="curve")
    cd.line([cx - rx * 0.4, cy - ry * 0.1, cx + rx * 0.2, cy + ry * 0.1], fill=(92, 132, 158, 120), width=3)


draw_corridor_puddle(300, 240, 58, 32)
draw_corridor_puddle(560, 320, 70, 36)

# inscriptions on both walls
cdd.rectangle([0, 12, COR_W - 1, 13], fill=(112, 140, 170, 70))
cdd.rectangle([0, 88, COR_W - 1, 89], fill=(112, 140, 170, 55))
cdd.rectangle([0, COR_H - 13, COR_W - 1, COR_H - 12], fill=(112, 140, 170, 70))
cdd.rectangle([0, COR_H - 89, COR_W - 1, COR_H - 88], fill=(112, 140, 170, 55))

gi = 0
for gx in range(58, COR_W - 30, 96):
    glyph(cgd, gx, 51, 38, gi % 10, ICE if gi % 3 else PALE, 4)
    glyph(cgd, gx, COR_H - 51, 38, (gi + 4) % 10, OCHRE if gi % 4 else ICE, 4)
    gi += 1

# slight wear
c_mask = Image.effect_noise((COR_W, COR_H), 82).convert("L").point(lambda v: 0 if v < 70 else 255)
c_md = ImageDraw.Draw(c_mask)
for _ in range(90):
    x0 = random.uniform(0, COR_W)
    y0 = random.uniform(0, COR_H)
    a = random.uniform(0, math.tau)
    ln = random.uniform(16, 120)
    c_md.line([x0, y0, x0 + math.cos(a) * ln, y0 + math.sin(a) * ln],
              fill=0, width=random.randint(1, 3))
r, g, b, a = c_glyph.split()
c_glyph.putalpha(ImageChops.multiply(a, c_mask))
c_glow = layer((COR_W, COR_H))
for blur, strength in ((12, 0.28), (5, 0.34)):
    ga = c_glyph.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
    ga = ga.point(lambda v: int(v * strength))
    bg = Image.new("RGBA", (COR_W, COR_H), (74, 138, 236, 255))
    bg.putalpha(ga)
    c_glow.alpha_composite(bg)
c_glow.alpha_composite(c_glyph)

# corridor walls (drawn before the inscriptions so the carvings sit on their face)
cd.rectangle([0, 0, COR_W - 1, WALL - 1], fill=WALL_BASE + (255,))
cd.rectangle([0, COR_H - WALL, COR_W - 1, COR_H - 1], fill=WALL_BASE + (255,))
for x in range(0, COR_W, BL):
    cd.rectangle([x + 3, 3, min(x + BL - 4, COR_W - 1), WALL - 4], fill=shade((56, 56, 58), 5) + (255,))
    cd.rectangle([x + 3, COR_H - WALL + 3, min(x + BL - 4, COR_W - 1), COR_H - 4], fill=shade((54, 54, 56), 5) + (255,))

CFACE = 38
cd.rectangle([0, WALL - CFACE, COR_W - 1, WALL - 1], fill=(35, 36, 39, 255))
cd.rectangle([0, COR_H - WALL, COR_W - 1, COR_H - WALL + CFACE - 1], fill=(35, 36, 39, 255))
for x in range(0, COR_W, BL):
    cd.line([x + 3, WALL - CFACE, x + 3, WALL - 1], fill=(23, 24, 26, 255), width=2)
    cd.line([x + 3, COR_H - WALL, x + 3, COR_H - WALL + CFACE - 1], fill=(23, 24, 26, 255), width=2)
cd.line([0, WALL - CFACE - 2, COR_W - 1, WALL - CFACE - 2], fill=(116, 118, 124, 255), width=4)
cd.line([0, COR_H - WALL + CFACE + 1, COR_W - 1, COR_H - WALL + CFACE + 1], fill=(116, 118, 124, 255), width=4)
cd.line([0, WALL, COR_W - 1, WALL], fill=(14, 15, 17, 255), width=3)
cd.line([0, COR_H - WALL - 1, COR_W - 1, COR_H - WALL - 1], fill=(14, 15, 17, 255), width=3)
cd.rectangle([0, 0, COR_W - 1, COR_H - 1], outline=(14, 15, 17, 255), width=4)

cimg.alpha_composite(c_deco)
cimg.alpha_composite(c_glow)

# corridor sconces in the walls
def corridor_sconce(cx, side):
    if side == "top":
        y0, y1 = 22, WALL - 1
        open_y = WALL - 1
    else:
        y0, y1 = COR_H - WALL, COR_H - 22
        open_y = COR_H - WALL
    cd.rectangle([cx - 66, y0, cx + 66, y1], fill=(13, 14, 18, 255))
    cd.rectangle([cx - 76, y0 - 8, cx + 76, y0], fill=(78, 79, 84, 255))
    cd.rectangle([cx - 76, y0 - 8, cx + 76, y0], outline=(32, 33, 36, 255), width=2)
    cd.rectangle([cx - 76, y0, cx - 66, y1], fill=(84, 85, 90, 255))
    cd.rectangle([cx + 66, y0, cx + 66 + 10, y1], fill=(84, 85, 90, 255))
    # bracket
    cd.line([cx, open_y, cx, open_y - 26], fill=IRON_DARK, width=6)
    cd.line([cx - 18, open_y - 20, cx + 18, open_y - 20], fill=IRON, width=5)
    add_glow(cimg, cx, open_y, 74, 48, (44, 116, 216, 72), 18)


corridor_sconce(240, "top")
corridor_sconce(510, "bottom")

# vignette
cvig = Image.new("L", (COR_W, COR_H), 0)
cvd = ImageDraw.Draw(cvig)
cvd.ellipse([-120, -120, COR_W + 120, COR_H + 120], fill=255)
cvig = cvig.filter(ImageFilter.GaussianBlur(140))
cdark = Image.new("RGBA", (COR_W, COR_H), (0, 2, 8, 92))
cdark.putalpha(ImageChops.subtract(Image.new("L", (COR_W, COR_H), 92), cvig))
cimg.alpha_composite(cdark)

cimg = pixelate(cimg, 40)
cor_path = os.path.join(OUT_DIR, "corridor_map.png")
cimg.convert("RGB").save(cor_path)

# pulsing overlay for the corridor inscriptions
c_glyph_px = pixelate_overlay(c_glow)
c_glyph_px.putalpha(ImageChops.multiply(
    c_glyph_px.getchannel("A"), ImageChops.invert(cdark.getchannel("A"))))
cor_glyph_path = os.path.join(OUT_DIR, "corridor_glyphs.png")
c_glyph_px.save(cor_glyph_path)

# ================================================================ SUMON RING
random.seed(73)
RING = 400
ring = Image.new("RGBA", (RING, RING), (0, 0, 0, 0))
rd = ImageDraw.Draw(ring)
rc = RING / 2


def ring_glow():
    g = Image.new("RGBA", (RING, RING), (0, 0, 0, 0))
    gd2 = ImageDraw.Draw(g)
    for rr, a in ((176, 110), (150, 90), (112, 80), (56, 60)):
        gd2.ellipse([rc - rr, rc - rr, rc + rr, rc + rr], outline=(70, 144, 255, a), width=10)
    ring.alpha_composite(g.filter(ImageFilter.GaussianBlur(14)))


ring_glow()
rd.ellipse([rc - 172, rc - 172, rc + 172, rc + 172], outline=(126, 190, 246, 235), width=9)
rd.ellipse([rc - 158, rc - 158, rc + 158, rc + 158], outline=(84, 144, 214, 210), width=4)
rd.ellipse([rc - 116, rc - 116, rc + 116, rc + 116], outline=(118, 178, 238, 220), width=5)
rd.ellipse([rc - 98, rc - 98, rc + 98, rc + 98], outline=(64, 118, 186, 170), width=2)
rd.ellipse([rc - 26, rc - 26, rc + 26, rc + 26], outline=(156, 214, 255, 230), width=5)
rd.ellipse([rc - 8, rc - 8, rc + 8, rc + 8], fill=(190, 232, 255, 235))

# star and spokes
for k in range(8):
    a = math.tau * k / 8
    rd.line([rc + math.cos(a) * 30, rc + math.sin(a) * 30,
             rc + math.cos(a) * 158, rc + math.sin(a) * 158],
            fill=(88, 150, 220, 120), width=3)
for k in range(4):
    a = math.tau * k / 4 + math.pi / 4
    b = a + math.tau * 2 / 4
    rd.line([rc + math.cos(a) * 116, rc + math.sin(a) * 116,
             rc + math.cos(b) * 116, rc + math.sin(b) * 116],
            fill=(112, 176, 238, 160), width=4)

# rune ring
for k in range(12):
    a = math.tau * k / 12 + math.pi / 12
    rx = rc + math.cos(a) * 138
    ry = rc + math.sin(a) * 138
    glyph(rd, rx, ry, 30, k % 10, (148, 204, 250, 220), 4)

ring = pixelate_rgba(ring)
ring_path = os.path.join(OUT_DIR, "summon_ring.png")
ring.save(ring_path)

# ============================================================ BLUE FLAME SHEET
random.seed(74)
FLAME_W, FLAME_H = 128, 160
FLAME_FRAMES = 6
FLAME_BASE_Y = 152
FLAME_MAIN_BASE_Y = 144
BLUE_PALETTE = ((28, 62, 176), (46, 122, 236), (116, 198, 255), (222, 246, 255))
BLUE_SPARK = (132, 208, 255)


def flame_tongue(dr, cx, base_y, height, max_half, seed, palette):
    steps = max(3, int(height / PIXEL))
    for i in range(steps):
        u = i / (steps - 1)
        y = base_y - i * PIXEL
        hw = max(PIXEL, px_snap(max_half * (1 - u) ** 0.6))
        wob = px_snap(math.sin(u * 5.2 + seed) * max_half * 0.35 * u)
        x = cx + wob
        px_block(dr, x - hw, y, x + hw, y + PIXEL, palette[0] + (255,))
        if hw >= PIXEL * 2:
            px_block(dr, x - hw * 0.70, y, x + hw * 0.70, y + PIXEL, palette[1] + (255,))
        if hw >= PIXEL * 3 and u < 0.82:
            px_block(dr, x - hw * 0.40, y, x + hw * 0.40, y + PIXEL, palette[2] + (255,))
        if hw >= PIXEL * 3 and u < 0.55:
            px_block(dr, x - hw * 0.18, y, x + hw * 0.18, y + PIXEL, palette[3] + (255,))


def blue_flame_frame(index):
    t = Image.new("RGBA", (FLAME_W, FLAME_H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(t)
    phase = index / FLAME_FRAMES * math.tau
    rng = random.Random(9200 + index)
    flame_tongue(dr, 41, FLAME_BASE_Y, 68 + math.sin(phase + 1.7) * 7, 17, 1.7 + phase * 0.55, BLUE_PALETTE)
    flame_tongue(dr, 87, FLAME_BASE_Y, 76 + math.sin(phase + 3.4) * 7, 17, 3.1 + phase * 0.55, BLUE_PALETTE)
    flame_tongue(dr, 64, FLAME_MAIN_BASE_Y, 96 + math.sin(phase) * 9, 27, 0.4 + phase * 0.55, BLUE_PALETTE)
    for _ in range(3):
        ex = px_snap(64 + rng.uniform(-52, 52))
        ey = px_snap(rng.uniform(16, 72))
        px_block(dr, ex, ey, ex + PIXEL, ey + PIXEL, BLUE_SPARK + (255,))
    return t


blue_sheet = Image.new("RGBA", (FLAME_W * FLAME_FRAMES, FLAME_H), (0, 0, 0, 0))
for i in range(FLAME_FRAMES):
    blue_sheet.alpha_composite(blue_flame_frame(i), (i * FLAME_W, 0))
blue_path = os.path.join(OUT_DIR, "torch_flame_blue.png")
blue_sheet.save(blue_path)

# ============================================================= WATER RIPPLE
random.seed(75)
RIP = 96
ripple = Image.new("RGBA", (RIP, RIP), (0, 0, 0, 0))
rid = ImageDraw.Draw(ripple)
rc2 = RIP / 2
for rr, alpha, width in ((34, 210, 5), (21, 130, 3)):
    g = Image.new("RGBA", (RIP, RIP), (0, 0, 0, 0))
    gd2 = ImageDraw.Draw(g)
    gd2.ellipse([rc2 - rr, rc2 - rr * 0.62, rc2 + rr, rc2 + rr * 0.62],
                outline=(130, 194, 220, alpha), width=width)
    ripple.alpha_composite(g.filter(ImageFilter.GaussianBlur(1.2)))
ripple_small = ripple.resize((RIP // 4, RIP // 4), Image.BOX)
ripple = ripple_small.resize((RIP, RIP), Image.NEAREST)
ripple_path = os.path.join(OUT_DIR, "water_ripple.png")
ripple.save(ripple_path)

print("saved", room_path, img.size)
print("saved", cor_path, cimg.size)
print("saved", cor_glyph_path, c_glyph_px.size)
print("saved", ring_path, ring.size)
print("saved", blue_path, blue_sheet.size)
print("saved", ripple_path, ripple.size)
