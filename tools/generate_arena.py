"""Generates the 2000x2000 top-down arena map texture for the Godot project."""

from PIL import Image, ImageDraw, ImageFilter, ImageChops
import random
import math
import os

W = H = 2000
WALL = 100
GATE_X0, GATE_X1 = 850, 1150
CENTER = W // 2

random.seed(23)

img = Image.new("RGBA", (W, H), (7, 7, 9, 255))
d = ImageDraw.Draw(img)

FLOOR_BASE = (82, 78, 73)
WALL_BASE = (50, 47, 43)
GROUT = (36, 34, 32)


def shade(c, amt):
    k = random.randint(-amt, amt)
    return tuple(max(0, min(255, int(v + k))) for v in c)


def tint(c, dr, dg, db, amt=0):
    return tuple(max(0, min(255, int(v + d + random.randint(-amt, amt)))) for v, d in zip(c, (dr, dg, db)))


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


# ------------------------------------------------------------------ floor
d.rectangle([WALL, WALL, W - WALL - 1, H - WALL - 1], fill=GROUT + (255,))
TILE = 154
row = 0
y = WALL
while y < H - WALL:
    offset = 0 if row % 2 == 0 else TILE // 2
    x = WALL - offset
    y2 = min(y + TILE - 4, H - WALL - 1)
    while x < W - WALL:
        x1 = max(WALL, x + 3)
        x2 = min(x + TILE - 4, W - WALL - 1)
        if x2 - x1 > 24:
            d.rectangle([x1, y + 3, x2, y2], fill=shade(FLOOR_BASE, 6) + (255,))
        x += TILE
    y += TILE
    row += 1

# stone pitting / chips
pits = layer()
pdd = ImageDraw.Draw(pits)
for _ in range(950):
    px = random.uniform(WALL + 6, W - WALL - 6)
    py = random.uniform(WALL + 6, H - WALL - 6)
    pr = random.uniform(0.7, 2.6)
    pdd.ellipse([px - pr, py - pr, px + pr, py + pr],
                fill=(28, 26, 24, random.randint(40, 90)))
    if random.random() < 0.35:
        pdd.ellipse([px - pr * 1.8 - 1, py - pr * 1.8 - 1, px - pr * 1.8 + 1, py - pr * 1.8 + 1],
                    fill=(118, 112, 100, 55))
for _ in range(160):
    px = random.uniform(WALL + 10, W - WALL - 10)
    py = random.uniform(WALL + 10, H - WALL - 10)
    pr = random.uniform(2, 5)
    pdd.ellipse([px - pr, py - pr * 0.7, px + pr, py + pr * 0.7],
                fill=(120, 114, 102, 35))
img.alpha_composite(pits)

# ambient occlusion around the walls
ao = layer()
ad = ImageDraw.Draw(ao)
for i in range(30):
    a = max(0, 115 - i * 4)
    ad.rectangle([WALL + i, WALL + i, W - WALL - 1 - i, H - WALL - 1 - i],
                 outline=(0, 0, 0, a), width=1)
img.alpha_composite(ao.filter(ImageFilter.GaussianBlur(12)))

# stone grain
for _ in range(2):
    n = Image.effect_noise((W, H), 22).convert("L")
    img.alpha_composite(Image.merge("RGBA", (n, n, n, Image.new("L", (W, H), 11))))

# --------------------------------------------------------------- glyphs
glyph_layer = layer()
gd = ImageDraw.Draw(glyph_layer)
OCHRE = (200, 152, 240, 238)
TEAL = (140, 140, 235, 228)


def glyph(dr, cx, cy, s, kind, color, w=3):
    w = 8  # thick strokes so glyphs survive the pixel-art downscale
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


INSET = 156
BAND = 94
MID = INSET + BAND / 2
STEP = 120
idx = 0

x = INSET + 70
while x <= W - INSET - 70:
    if not (GATE_X0 - 60 <= x <= GATE_X1 + 60):
        glyph(gd, x, MID, 58, idx % 10, TEAL if idx % 7 == 3 else OCHRE, 3)
        idx += 1
    x += STEP

x = INSET + 70
while x <= W - INSET - 70:
    glyph(gd, x, H - MID, 58, idx % 10, TEAL if idx % 7 == 3 else OCHRE, 3)
    idx += 1
    x += STEP

y = INSET + 70
while y <= H - INSET - 70:
    glyph(gd, MID, y, 58, idx % 10, TEAL if idx % 7 == 3 else OCHRE, 3)
    idx += 1
    glyph(gd, W - MID, y, 58, idx % 10, TEAL if idx % 7 == 3 else OCHRE, 3)
    idx += 1
    y += STEP

gd.rectangle([INSET, INSET, W - INSET, H - INSET], outline=(158, 130, 80, 95), width=4)
gd.rectangle([INSET + BAND, INSET + BAND, W - INSET - BAND, H - INSET - BAND],
             outline=(158, 130, 80, 75), width=3)

# central emblem
gd.ellipse([CENTER - 300, CENTER - 300, CENTER + 300, CENTER + 300], outline=(166, 138, 86, 140), width=6)
gd.ellipse([CENTER - 278, CENTER - 278, CENTER + 278, CENTER + 278], outline=(166, 138, 86, 95), width=2)
for k in range(4):
    a = math.pi / 2 * k + math.pi / 4
    glyph(gd, CENTER + math.cos(a) * 190, CENTER + math.sin(a) * 190, 64, (k * 3) % 10, OCHRE, 3)
gd.ellipse([CENTER - 24, CENTER - 24, CENTER + 24, CENTER + 24], outline=OCHRE, width=4)
gd.line([CENTER - 17, CENTER, CENTER + 17, CENTER], fill=OCHRE, width=3)
gd.line([CENTER, CENTER - 17, CENTER, CENTER + 17], fill=OCHRE, width=3)

# paint wear: noise erosion + scratches
noise = Image.effect_noise((W, H), 82).convert("L")
mask = noise.point(lambda v: 0 if v < 68 else 255)
md = ImageDraw.Draw(mask)
for _ in range(200):
    x0 = random.uniform(INSET, W - INSET)
    y0 = random.uniform(INSET, H - INSET)
    ang = random.uniform(0, math.tau)
    ln = random.uniform(20, 160)
    md.line([x0, y0, x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln],
            fill=0, width=random.randint(1, 4))
r, g, b, a = glyph_layer.split()
glyph_layer.putalpha(ImageChops.multiply(a, mask))

glyph_overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))

# faint purple luminescence behind the carvings
for blur, strength in ((18, 0.48), (7, 0.38)):
    glow_a = glyph_layer.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
    glow_a = glow_a.point(lambda v: int(v * strength))
    purple_glow = Image.new("RGBA", (W, H), (164, 96, 242, 255))
    purple_glow.putalpha(glow_a)
    glyph_overlay.alpha_composite(purple_glow)

glyph_overlay.alpha_composite(glyph_layer)
img.alpha_composite(glyph_overlay)

# ------------------------------------------------------- cracks + scratches
hi = layer()
hd = ImageDraw.Draw(hi)


def crack(x, y, steps, angle, width, color=(24, 22, 20, 255), branch=True):
    pts = [(x, y)]
    for _ in range(steps):
        angle += random.uniform(-0.55, 0.55)
        x += math.cos(angle) * random.uniform(8, 24)
        y += math.sin(angle) * random.uniform(8, 24)
        pts.append((x, y))
    d.line(pts, fill=color, width=width, joint="curve")
    hd.line([(px + 1.5, py + 1.5) for px, py in pts], fill=(132, 124, 112, 55), width=1)
    if branch and random.random() < 0.5:
        bx, by = random.choice(pts)
        crack(bx, by, random.randint(2, 5), angle + random.uniform(-1.2, 1.2), 2, branch=False)


for _ in range(22):
    crack(random.uniform(WALL + 30, W - WALL - 30),
          random.uniform(WALL + 30, H - WALL - 30),
          random.randint(6, 14), random.uniform(0, math.tau), random.randint(2, 3))

for _ in range(190):
    x0 = random.uniform(WALL + 20, W - WALL - 20)
    y0 = random.uniform(WALL + 20, H - WALL - 20)
    ang = random.uniform(0, math.tau)
    ln = random.uniform(30, 180)
    col = (138, 130, 118, random.randint(40, 90)) if random.random() < 0.75 else (26, 24, 22, 85)
    hd.line([x0, y0, x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln],
            fill=col, width=random.choice([1, 1, 2]))
    if random.random() < 0.22:  # claw marks
        for k in range(3):
            off = (k - 1) * 9
            ox = math.cos(ang + 1.57) * off
            oy = math.sin(ang + 1.57) * off
            hd.line([x0 + ox, y0 + oy, x0 + ox + math.cos(ang) * ln, y0 + oy + math.sin(ang) * ln],
                    fill=col, width=1)
img.alpha_composite(hi)

# ----------------------------------------------------------------- blood
blood = layer()
bd = ImageDraw.Draw(blood)


def blood_patch(cx, cy, r, strength=1.0):
    n = random.randint(9, 14)
    pts = []
    for i in range(n):
        a = math.tau * i / n
        rr = r * random.uniform(0.35, 0.85)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * random.uniform(0.7, 1.0)))
    bd.polygon(pts, fill=(random.randint(48, 62), random.randint(10, 16),
                         random.randint(8, 13), int(110 * strength)))
    for _ in range(random.randint(6, 10)):
        ox = random.uniform(-r * 0.9, r * 0.9)
        oy = random.uniform(-r * 0.9, r * 0.9)
        rx = random.uniform(r * 0.06, r * 0.2)
        ry = rx * random.uniform(0.6, 1.3)
        bd.ellipse([cx + ox - rx, cy + oy - ry, cx + ox + rx, cy + oy + ry],
                   fill=(random.randint(46, 64), random.randint(10, 17), random.randint(8, 14),
                         int(random.randint(70, 120) * strength)))
    for _ in range(2):  # dried core
        ox = random.uniform(-r * 0.2, r * 0.2)
        oy = random.uniform(-r * 0.2, r * 0.2)
        rx = random.uniform(r * 0.08, r * 0.18)
        bd.ellipse([cx + ox - rx, cy + oy - rx, cx + ox + rx, cy + oy + rx],
                   fill=(28, 6, 5, int(90 * strength)))
    for _ in range(random.randint(12, 24)):  # droplets
        ang = random.uniform(0, math.tau)
        dist = random.uniform(r * 0.5, r * 1.5)
        dr = random.uniform(1, 4)
        bd.ellipse([cx + math.cos(ang) * dist - dr, cy + math.sin(ang) * dist - dr,
                    cx + math.cos(ang) * dist + dr, cy + math.sin(ang) * dist + dr],
                   fill=(44, 10, 8, int(random.randint(50, 100) * strength)))


for _ in range(5):
    blood_patch(random.uniform(INSET + 100, W - INSET - 100),
                random.uniform(INSET + 100, H - INSET - 100),
                random.uniform(60, 150))

# dried trail from the gate
tx, ty = CENTER, WALL + 6
for i in range(24):
    tx += random.uniform(-12, 12)
    ty += random.uniform(10, 18)
    rr = random.uniform(6, 20) * (1.0 - i / 40.0)
    bd.ellipse([tx - rr, ty - rr * 0.7, tx + rr, ty + rr * 0.7],
               fill=(44, 9, 7, random.randint(45, 95)))
img.alpha_composite(blood.filter(ImageFilter.GaussianBlur(1.8)))

# ------------------------------------------------------------------ moss
moss = layer()
msd = ImageDraw.Draw(moss)


def moss_cluster(cx, cy, r, n=16, alpha=100):
    for _ in range(n):
        ox = random.uniform(-r, r)
        oy = random.uniform(-r, r)
        rr = random.uniform(r * 0.12, r * 0.34)
        msd.ellipse([cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr],
                    fill=(random.randint(40, 64), random.randint(66, 96), random.randint(34, 52), alpha))


for _ in range(14):
    side = random.randint(0, 3)
    if side == 0:
        moss_cluster(random.uniform(WALL + 40, W - WALL - 40), random.uniform(WALL + 24, WALL + 80), random.uniform(18, 44))
    elif side == 1:
        moss_cluster(random.uniform(WALL + 40, W - WALL - 40), random.uniform(H - WALL - 80, H - WALL - 24), random.uniform(18, 44))
    elif side == 2:
        moss_cluster(random.uniform(WALL + 24, WALL + 80), random.uniform(WALL + 40, H - WALL - 40), random.uniform(18, 44))
    else:
        moss_cluster(random.uniform(W - WALL - 80, W - WALL - 24), random.uniform(WALL + 40, H - WALL - 40), random.uniform(18, 44))

for _ in range(7):
    moss_cluster(random.uniform(INSET, W - INSET), random.uniform(INSET, H - INSET), random.uniform(12, 30), 9, 65)

img.alpha_composite(moss.filter(ImageFilter.GaussianBlur(2)))

# ------------------------------------------------------------- pebbles/rocks
shadow = layer()
shd = ImageDraw.Draw(shadow)


def rock(cx, cy, r):
    shd.ellipse([cx - r * 1.05 + 3, cy - r * 0.8 + 4, cx + r * 1.05 + 3, cy + r * 0.8 + 4],
                fill=(0, 0, 0, 95))
    pts = []
    n = random.randint(6, 9)
    for i in range(n):
        a = math.tau * i / n
        rr = r * random.uniform(0.7, 1.15)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.85))
    d.polygon(pts, fill=shade((84, 80, 74), 10) + (255,))
    d.line(pts + [pts[0]], fill=(32, 30, 28, 255), width=2, joint="curve")
    d.line([pts[0], pts[1]], fill=(126, 120, 108, 255), width=2)


for _ in range(20):
    gx = random.uniform(INSET + 60, W - INSET - 60)
    gy = random.uniform(INSET + 60, H - INSET - 60)
    for _ in range(random.randint(2, 5)):
        rock(gx + random.uniform(-34, 34), gy + random.uniform(-26, 26), random.uniform(5, 16))

img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(3)))

# ------------------------------------------------------------------ walls
d.rectangle([0, 0, W - 1, WALL - 1], fill=WALL_BASE + (255,))
d.rectangle([0, H - WALL, W - 1, H - 1], fill=WALL_BASE + (255,))
d.rectangle([0, 0, WALL - 1, H - 1], fill=WALL_BASE + (255,))
d.rectangle([W - WALL, 0, W - 1, H - 1], fill=WALL_BASE + (255,))

BL = 142
for x in range(0, W, BL):
    d.rectangle([x + 3, 3, min(x + BL - 4, W - 1), WALL - 4], fill=shade((58, 54, 50), 5) + (255,))
    d.rectangle([x + 3, H - WALL + 3, min(x + BL - 4, W - 1), H - 4], fill=shade((55, 51, 47), 5) + (255,))
for yy in range(WALL, H - WALL, BL):
    d.rectangle([3, yy + 3, WALL - 4, min(yy + BL - 4, H - WALL - 1)], fill=shade((56, 52, 48), 5) + (255,))
    d.rectangle([W - WALL + 3, yy + 3, W - 4, min(yy + BL - 4, H - WALL - 1)], fill=shade((56, 52, 48), 5) + (255,))

# wall cracks
for _ in range(18):
    side = random.randint(0, 3)
    if side == 0:
        crack(random.uniform(0, W), random.uniform(6, WALL - 6), random.randint(4, 9), random.uniform(0, math.tau), 2)
    elif side == 1:
        crack(random.uniform(0, W), random.uniform(H - WALL + 6, H - 6), random.randint(4, 9), random.uniform(0, math.tau), 2)
    elif side == 2:
        crack(random.uniform(6, WALL - 6), random.uniform(0, H), random.randint(4, 9), random.uniform(0, math.tau), 2)
    else:
        crack(random.uniform(W - WALL + 6, W - 6), random.uniform(0, H), random.randint(4, 9), random.uniform(0, math.tau), 2)

# --- raised walls: inner face, bevel, cast shadow ---
FACE = 38
d.rectangle([WALL, WALL - FACE, W - WALL - 1, WALL - 1], fill=(38, 35, 32, 255))
d.rectangle([WALL, H - WALL, W - WALL - 1, H - WALL + FACE - 1], fill=(38, 35, 32, 255))
d.rectangle([WALL - FACE, WALL, WALL - 1, H - WALL - 1], fill=(38, 35, 32, 255))
d.rectangle([W - WALL, WALL, W - WALL + FACE - 1, H - WALL - 1], fill=(38, 35, 32, 255))

# block seams on the inner face
for x in range(0, W, BL):
    d.line([x + 3, WALL - FACE, x + 3, WALL - 1], fill=(25, 23, 21, 255), width=2)
    d.line([x + 3, H - WALL, x + 3, H - WALL + FACE - 1], fill=(25, 23, 21, 255), width=2)
for yy in range(0, H, BL):
    d.line([WALL - FACE, yy + 3, WALL - 1, yy + 3], fill=(25, 23, 21, 255), width=2)
    d.line([W - WALL, yy + 3, W - WALL + FACE - 1, yy + 3], fill=(25, 23, 21, 255), width=2)

# bright top bevel at the junction of the cap and the inner face
d.line([0, WALL - FACE - 2, W - 1, WALL - FACE - 2], fill=(118, 112, 102, 255), width=4)
d.line([0, H - WALL + FACE + 1, W - 1, H - WALL + FACE + 1], fill=(118, 112, 102, 255), width=4)
d.line([WALL - FACE - 2, 0, WALL - FACE - 2, H - 1], fill=(118, 112, 102, 255), width=4)
d.line([W - WALL + FACE + 1, 0, W - WALL + FACE + 1, H - 1], fill=(118, 112, 102, 255), width=4)

# wide cast shadow on the floor so the walls read as tall
raise_sh = layer()
rsd = ImageDraw.Draw(raise_sh)
for i in range(80):
    a = int(180 * (1 - i / 80) ** 1.45)
    rsd.rectangle([WALL + i, WALL + i, W - WALL - 1 - i, H - WALL - 1 - i],
                  outline=(0, 0, 0, a), width=1)
img.alpha_composite(raise_sh.filter(ImageFilter.GaussianBlur(10)))

# dark base line where the wall meets the floor
d.line([WALL, WALL, W - WALL - 1, WALL], fill=(16, 15, 14, 255), width=3)
d.line([WALL, H - WALL - 1, W - WALL - 1, H - WALL - 1], fill=(16, 15, 14, 255), width=3)
d.line([WALL, WALL, WALL, H - WALL - 1], fill=(16, 15, 14, 255), width=3)
d.line([W - WALL - 1, WALL, W - WALL - 1, H - WALL - 1], fill=(16, 15, 14, 255), width=3)

# outer rim
d.rectangle([0, 0, W - 1, H - 1], outline=(16, 15, 14, 255), width=6)
d.rectangle([2, 2, W - 3, H - 3], outline=(86, 81, 74, 255), width=2)

# wall moss in the seams
wmoss = layer()
wmd = ImageDraw.Draw(wmoss)
for _ in range(50):
    side = random.randint(0, 3)
    if side == 0:
        cx, cy = random.uniform(0, W), random.uniform(8, WALL - 8)
    elif side == 1:
        cx, cy = random.uniform(0, W), random.uniform(H - WALL + 8, H - 8)
    elif side == 2:
        cx, cy = random.uniform(8, WALL - 8), random.uniform(0, H)
    else:
        cx, cy = random.uniform(W - WALL + 8, W - 8), random.uniform(0, H)
    for _ in range(random.randint(3, 8)):
        rr = random.uniform(2, 7)
        ox = random.uniform(-10, 10)
        oy = random.uniform(-8, 8)
        wmd.ellipse([cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr],
                    fill=(random.randint(42, 62), random.randint(64, 92), random.randint(34, 50), 95))
img.alpha_composite(wmoss.filter(ImageFilter.GaussianBlur(1.5)))

# ------------------------------------------------------------------- gate
d.rectangle([GATE_X0 - 48, 0, GATE_X0 - 1, WALL - 1], fill=(94, 87, 78, 255))
d.rectangle([GATE_X1, 0, GATE_X1 + 48, WALL - 1], fill=(94, 87, 78, 255))
for i in range(WALL):
    t = i / WALL
    c = int(26 - 12 * t)
    d.line([GATE_X0, i, GATE_X1 - 1, i], fill=(max(3, c), max(3, c - 2), max(3, c - 4), 255))
for bx in range(GATE_X0 + 16, GATE_X1 - 8, 30):
    d.line([bx, 2, bx, WALL - 3], fill=(52, 47, 42, 255), width=6)
    d.line([bx - 2, 2, bx - 2, WALL - 3], fill=(98, 90, 80, 255), width=2)
d.line([GATE_X0 + 4, WALL // 2, GATE_X1 - 5, WALL // 2], fill=(60, 54, 48, 255), width=8)
d.rectangle([GATE_X0 - 48, 0, GATE_X0 - 1, WALL - 1], outline=(40, 36, 32, 255), width=2)
d.rectangle([GATE_X1, 0, GATE_X1 + 48, WALL - 1], outline=(40, 36, 32, 255), width=2)
d.rectangle([GATE_X0 - 4, WALL - 8, GATE_X1 + 3, WALL + 10], fill=(70, 65, 59, 255))

# gate shadow inside the arena
gs = layer()
gsh = ImageDraw.Draw(gs)
gsh.rectangle([GATE_X0, WALL, GATE_X1, WALL + 30], fill=(0, 0, 0, 115))
img.alpha_composite(gs.filter(ImageFilter.GaussianBlur(11)))

# ---------------------------------------------------------------- pillars
PILLARS = [(-500, -840), (500, -840), (-500, 840), (500, 840),
           (-840, -500), (-840, 500), (840, -500), (840, 500)]


def draw_pillar(px, py):
    ps = layer()
    pd = ImageDraw.Draw(ps)
    pd.ellipse([px - 72, py - 56, px + 76, py + 70], fill=(0, 0, 0, 130))
    img.alpha_composite(ps.filter(ImageFilter.GaussianBlur(9)))
    d.rectangle([px - 62, py - 62, px + 62, py + 62], fill=(38, 36, 33, 255))
    d.rectangle([px - 56, py - 56, px + 56, py + 56], fill=(64, 60, 55, 255))
    d.line([px - 56, py - 56, px + 56, py - 56], fill=(96, 90, 82, 255), width=3)
    d.line([px - 56, py - 56, px - 56, py + 56], fill=(88, 82, 74, 255), width=3)
    d.line([px + 56, py - 56, px + 56, py + 56], fill=(36, 33, 30, 255), width=3)
    d.line([px - 56, py + 56, px + 56, py + 56], fill=(36, 33, 30, 255), width=3)
    d.rectangle([px - 42, py - 42, px + 42, py + 42], fill=(82, 77, 70, 255))
    d.rectangle([px - 42, py - 42, px + 42, py + 42], outline=(32, 30, 27, 255), width=2)
    d.line([px - 38, py - 38, px + 38, py - 38], fill=(110, 103, 92, 255), width=2)
    d.line([px - 38, py - 38, px - 38, py + 38], fill=(102, 95, 85, 255), width=2)
    crack(px + random.uniform(-26, 10), py - 38, random.randint(2, 4), random.uniform(1.2, 1.9), 2)
    for _ in range(4):
        rr = random.uniform(2, 5)
        ox = random.uniform(-40, 40)
        oy = random.uniform(-40, 40)
        d.ellipse([px + ox - rr, py + oy - rr, px + ox + rr, py + oy + rr],
                  fill=(48, 62, 38, 160))


for wx, wy in PILLARS:
    draw_pillar(wx + 1000, wy + 1000)

# ------------------------------------------------------------------ skulls
def skull_tile(size, tint=(198, 188, 166), aged=False):
    s = int(size)
    t = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(t)
    sd.ellipse([s * 0.14, s * 0.10, s * 0.86, s * 0.66], fill=tint + (255,))
    sd.rounded_rectangle([s * 0.27, s * 0.46, s * 0.73, s * 0.86], radius=int(s * 0.13), fill=tint + (255,))
    dark = (32, 27, 22, 255)
    sd.ellipse([s * 0.22, s * 0.28, s * 0.45, s * 0.50], fill=dark)
    sd.ellipse([s * 0.55, s * 0.28, s * 0.78, s * 0.50], fill=dark)
    sd.polygon([(s * 0.5, s * 0.46), (s * 0.43, s * 0.60), (s * 0.57, s * 0.60)], fill=dark)
    for i in range(4):
        xx = s * 0.34 + i * s * 0.09
        sd.line([(xx, s * 0.65), (xx, s * 0.80)], fill=(76, 66, 54, 255), width=max(1, int(s * 0.025)))
    sd.arc([s * 0.14, s * 0.10, s * 0.86, s * 0.66], 200, 340, fill=(146, 136, 116, 255), width=max(1, int(s * 0.02)))
    sd.ellipse([s * 0.30, s * 0.16, s * 0.46, s * 0.28], fill=(226, 218, 198, 90))
    if aged:
        for _ in range(9):  # grime
            ox = random.uniform(0.16, 0.84) * s
            oy = random.uniform(0.12, 0.82) * s
            rr = random.uniform(0.05, 0.13) * s
            sd.ellipse([ox - rr, oy - rr * 0.8, ox + rr, oy + rr * 0.8], fill=(58, 50, 39, 60))
        pts = [(s * 0.46, s * 0.12), (s * 0.54, s * 0.26), (s * 0.46, s * 0.38), (s * 0.53, s * 0.52)]
        sd.line(pts, fill=(74, 64, 51, 200), width=max(1, int(s * 0.022)))
        sd.line([(s * 0.435, s * 0.64), (s * 0.435, s * 0.81)], fill=(18, 16, 14, 255),
                width=max(2, int(s * 0.045)))
        alpha = t.getchannel("A")
        ad2 = ImageDraw.Draw(alpha)
        for _ in range(5):  # chipped edges
            ox = random.choice([random.uniform(0.05, 0.18), random.uniform(0.82, 0.95)]) * s
            oy = random.uniform(0.18, 0.62) * s
            rr = random.uniform(0.03, 0.07) * s
            ad2.ellipse([ox - rr, oy - rr, ox + rr, oy + rr], fill=0)
        t.putalpha(alpha)
    return t


def paste_skull(cx, cy, size, angle=0, tint=(198, 188, 166), aged=False):
    sh = layer()
    shd = ImageDraw.Draw(sh)
    shd.ellipse([cx - size * 0.42 + 3, cy - size * 0.30 + 4, cx + size * 0.42 + 3, cy + size * 0.40 + 4],
                fill=(0, 0, 0, 85))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))
    t = skull_tile(size, tint, aged)
    t = t.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(t, (int(cx - t.width / 2), int(cy - t.height / 2)))


# scattered around two corners
for cx, cy, sz, ang in [
    (300, 1650, 64, -18), (238, 1742, 52, 24), (386, 1758, 46, 8),
    (1652, 1698, 58, 14), (1740, 1616, 48, -26),
]:
    paste_skull(cx, cy, sz, ang)

# ------------------------------------------------- skeletons & broken armor
BONE = (184, 174, 154)
BONE_EDGE = (48, 42, 34)


def bone_seg(dr, x1, y1, x2, y2, w):
    w = max(4, int(round(w * 1.8)))  # bolder bones survive the pixel-art downscale
    dr.line([x1, y1, x2, y2], fill=BONE_EDGE + (255,), width=w + 2)
    dr.line([x1, y1, x2, y2], fill=BONE + (255,), width=w)
    for x, y in ((x1, y1), (x2, y2)):
        dr.ellipse([x - w * 1.1, y - w * 1.1, x + w * 1.1, y + w * 1.1], fill=BONE_EDGE + (255,))
        dr.ellipse([x - w * 0.7, y - w * 0.7, x + w * 0.7, y + w * 0.7], fill=BONE + (255,))


def skeleton_tile(length):
    s = int(length)
    t = Image.new("RGBA", (s, int(s * 0.96)), (0, 0, 0, 0))
    sd = ImageDraw.Draw(t)
    w, h = t.size
    cx = w / 2

    sk = skull_tile(s * 0.25, tint=(174, 164, 142), aged=True)
    sk_top = h * 0.02
    t.alpha_composite(sk, (int(cx - sk.width / 2), int(sk_top)))
    neck_top = sk_top + sk.height * 0.88

    # neck + spine
    spine_top = neck_top + h * 0.035
    spine_bot = h * 0.60
    bone_seg(sd, cx, neck_top, cx, spine_top, 2)
    for i in range(8):
        yy = spine_top + i * (spine_bot - spine_top) / 8
        bone_seg(sd, cx, yy, cx, yy + (spine_bot - spine_top) / 11, 2)

    # clavicles
    sd.line([cx - w * 0.14, spine_top + h * 0.012, cx + w * 0.14, spine_top + h * 0.012],
            fill=BONE_EDGE + (255,), width=7)
    sd.line([cx - w * 0.14, spine_top + h * 0.012, cx + w * 0.14, spine_top + h * 0.012],
            fill=BONE + (255,), width=4)

    # ribcage
    for i in range(5):
        yy = spine_top + h * 0.045 + i * h * 0.05
        for side in (-1, 1):
            pts = []
            for k in range(7):
                tt = k / 6
                xx = cx + side * (w * 0.025 + tt * w * 0.15) * (1 - i * 0.06)
                pts.append((xx, yy + math.sin(tt * math.pi * 0.9) * h * 0.035 + tt * h * 0.012))
            sd.line(pts, fill=BONE_EDGE + (255,), width=7, joint="curve")
            sd.line(pts, fill=BONE + (255,), width=4, joint="curve")

    # pelvis
    py = h * 0.62
    sd.ellipse([cx - w * 0.13, py, cx - w * 0.01, py + h * 0.09], outline=BONE_EDGE + (255,), width=7)
    sd.ellipse([cx + w * 0.01, py, cx + w * 0.13, py + h * 0.09], outline=BONE_EDGE + (255,), width=7)
    sd.ellipse([cx - w * 0.13, py, cx - w * 0.01, py + h * 0.09], outline=BONE + (255,), width=4)
    sd.ellipse([cx + w * 0.01, py, cx + w * 0.13, py + h * 0.09], outline=BONE + (255,), width=4)
    sd.polygon([(cx, py + h * 0.005), (cx - w * 0.035, py + h * 0.08),
                (cx + w * 0.035, py + h * 0.08)], fill=BONE + (255,))

    # arms
    bone_seg(sd, cx - w * 0.12, spine_top + h * 0.02, cx - w * 0.22, h * 0.44, 3)
    bone_seg(sd, cx - w * 0.22, h * 0.44, cx - w * 0.18, h * 0.55, 2)
    bone_seg(sd, cx + w * 0.12, spine_top + h * 0.02, cx + w * 0.23, h * 0.42, 3)
    bone_seg(sd, cx + w * 0.23, h * 0.42, cx + w * 0.19, h * 0.54, 2)

    # legs
    bone_seg(sd, cx - w * 0.05, py + h * 0.09, cx - w * 0.14, h * 0.78, 3)
    bone_seg(sd, cx - w * 0.14, h * 0.78, cx - w * 0.16, h * 0.94, 2)
    bone_seg(sd, cx + w * 0.05, py + h * 0.09, cx + w * 0.15, h * 0.77, 3)
    bone_seg(sd, cx + w * 0.15, h * 0.77, cx + w * 0.17, h * 0.93, 2)

    # fingers / toes
    for fx, fy in [(cx - w * 0.18, h * 0.56), (cx + w * 0.19, h * 0.55),
                   (cx - w * 0.16, h * 0.94), (cx + w * 0.17, h * 0.93)]:
        for k in range(3):
            a = -0.7 + k * 0.7
            sd.line([fx, fy, fx + math.cos(a) * w * 0.028, fy + math.sin(a) * w * 0.028],
                    fill=BONE + (255,), width=4)
    return t


def paste_piece(t, cx, cy):
    sh = layer()
    shd = ImageDraw.Draw(sh)
    shd.ellipse([cx - t.width * 0.28 + 3, cy - t.height * 0.22 + 4,
                 cx + t.width * 0.28 + 3, cy + t.height * 0.22 + 4], fill=(0, 0, 0, 65))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5)))
    img.alpha_composite(t, (int(cx - t.width / 2), int(cy - t.height / 2)))


def paste_skeleton(cx, cy, length, angle):
    paste_piece(skeleton_tile(length).rotate(angle, resample=Image.BICUBIC, expand=True), cx, cy)


def armor_chest(cx, cy, size, angle):
    t = Image.new("RGBA", (int(size * 1.6), int(size * 1.5)), (0, 0, 0, 0))
    dr = ImageDraw.Draw(t)
    w, h = t.size
    # pauldrons
    dr.ellipse([w * 0.08, h * 0.12, w * 0.30, h * 0.36], fill=(84, 78, 70, 255))
    dr.ellipse([w * 0.08, h * 0.12, w * 0.30, h * 0.36], outline=(30, 28, 24, 255), width=3)
    dr.ellipse([w * 0.70, h * 0.12, w * 0.92, h * 0.36], fill=(84, 78, 70, 255))
    dr.ellipse([w * 0.70, h * 0.12, w * 0.92, h * 0.36], outline=(30, 28, 24, 255), width=3)
    pts = [(w * 0.20, h * 0.24), (w * 0.34, h * 0.16), (w * 0.50, h * 0.22),
           (w * 0.66, h * 0.16), (w * 0.80, h * 0.24), (w * 0.77, h * 0.54),
           (w * 0.72, h * 0.72), (w * 0.63, h * 0.66), (w * 0.56, h * 0.80),
           (w * 0.47, h * 0.68), (w * 0.39, h * 0.79), (w * 0.31, h * 0.64),
           (w * 0.22, h * 0.58)]
    dr.polygon(pts, fill=(92, 86, 76, 255))
    dr.line(pts + [pts[0]], fill=(30, 28, 24, 255), width=4, joint="curve")
    dr.ellipse([w * 0.42, h * 0.14, w * 0.58, h * 0.30], fill=(26, 24, 21, 255))
    dr.line([w * 0.50, h * 0.30, w * 0.50, h * 0.64], fill=(122, 114, 102, 255), width=2)
    dr.line([w * 0.32, h * 0.30, w * 0.43, h * 0.36], fill=(122, 114, 102, 255), width=2)
    dr.line([w * 0.68, h * 0.30, w * 0.57, h * 0.36], fill=(122, 114, 102, 255), width=2)
    dr.ellipse([w * 0.55, h * 0.44, w * 0.69, h * 0.58], fill=(24, 22, 20, 255))
    dr.ellipse([w * 0.55, h * 0.44, w * 0.69, h * 0.58], outline=(52, 46, 40, 255), width=2)
    for _ in range(12):
        ox = random.uniform(w * 0.22, w * 0.78)
        oy = random.uniform(h * 0.2, h * 0.75)
        rr = random.uniform(2, 7)
        dr.ellipse([ox - rr, oy - rr, ox + rr, oy + rr], fill=(98, 56, 33, 120))
    for rx, ry in [(w * 0.28, h * 0.28), (w * 0.72, h * 0.28), (w * 0.26, h * 0.52), (w * 0.74, h * 0.52)]:
        dr.ellipse([rx - 3, ry - 3, rx + 3, ry + 3], fill=(70, 64, 56, 255))
    paste_piece(t.rotate(angle, expand=True, resample=Image.BICUBIC), cx, cy)


def armor_helmet(cx, cy, size, angle):
    s = int(size)
    t = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(t)
    dr.ellipse([s * 0.12, s * 0.18, s * 0.88, s * 0.82], fill=(90, 84, 75, 255))
    dr.ellipse([s * 0.12, s * 0.18, s * 0.88, s * 0.82], outline=(28, 26, 23, 255), width=4)
    dr.rectangle([s * 0.22, s * 0.40, s * 0.78, s * 0.50], fill=(20, 18, 16, 255))
    dr.line([s * 0.5, s * 0.18, s * 0.58, s * 0.34, s * 0.52, s * 0.44], fill=(34, 30, 26, 255), width=3)
    for k in range(5):
        a = math.pi + k * math.pi / 4
        rx = s * 0.5 + math.cos(a) * s * 0.33
        ry = s * 0.5 + math.sin(a) * s * 0.30
        dr.ellipse([rx - 3, ry - 3, rx + 3, ry + 3], fill=(116, 108, 96, 255))
    paste_piece(t.rotate(angle, expand=True, resample=Image.BICUBIC), cx, cy)


def armor_shield(cx, cy, size, angle):
    s = int(size)
    t = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(t)
    dr.ellipse([s * 0.10, s * 0.12, s * 0.90, s * 0.88], fill=(90, 84, 75, 255))
    dr.ellipse([s * 0.10, s * 0.12, s * 0.90, s * 0.88], outline=(26, 24, 21, 255), width=4)
    dr.ellipse([s * 0.15, s * 0.17, s * 0.85, s * 0.83], outline=(124, 116, 104, 255), width=2)
    dr.ellipse([s * 0.34, s * 0.38, s * 0.66, s * 0.66], fill=(116, 108, 96, 255))
    dr.ellipse([s * 0.34, s * 0.38, s * 0.66, s * 0.66], outline=(30, 28, 25, 255), width=3)
    dr.arc([s * 0.38, s * 0.42, s * 0.62, s * 0.62], 200, 320, fill=(150, 142, 130, 255), width=2)
    for k in range(8):
        a = math.tau * k / 8
        rx = s * 0.5 + math.cos(a) * s * 0.33
        ry = s * 0.5 + math.sin(a) * s * 0.31
        dr.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(110, 102, 90, 255))
    alpha = t.getchannel("A")
    ad2 = ImageDraw.Draw(alpha)
    ad2.polygon([(s * 0.70, s * 0.10), (s * 1.02, s * 0.00), (s * 0.98, s * 0.30), (s * 0.78, s * 0.26)], fill=0)
    t.putalpha(alpha)
    paste_piece(t.rotate(angle, expand=True, resample=Image.BICUBIC), cx, cy)


def armor_sword(cx, cy, length, angle):
    s = int(length)
    t = Image.new("RGBA", (s, max(8, int(s * 0.24))), (0, 0, 0, 0))
    dr = ImageDraw.Draw(t)
    w, h = t.size
    dr.line([w * 0.12, h * 0.5, w * 0.80, h * 0.5], fill=(28, 26, 23, 255), width=9)
    dr.line([w * 0.12, h * 0.5, w * 0.80, h * 0.5], fill=(118, 112, 100, 255), width=5)
    dr.line([w * 0.16, h * 0.44, w * 0.76, h * 0.44], fill=(146, 140, 128, 255), width=1)
    dr.polygon([(w * 0.80, h * 0.34), (w * 0.92, h * 0.5), (w * 0.80, h * 0.66)], fill=(118, 112, 100, 255))
    dr.line([w * 0.10, h * 0.28, w * 0.10, h * 0.72], fill=(88, 70, 48, 255), width=7)
    dr.line([w * 0.02, h * 0.5, w * 0.10, h * 0.5], fill=(74, 58, 40, 255), width=7)
    paste_piece(t.rotate(angle, expand=True, resample=Image.BICUBIC), cx, cy)


# bottom-left pile
paste_skeleton(470, 1520, 250, -22)
paste_skeleton(650, 1690, 210, 38)
armor_chest(560, 1610, 92, 30)
armor_helmet(612, 1512, 64, -12)
armor_sword(430, 1690, 150, 24)
# bottom-right pile
paste_skeleton(1510, 1580, 230, 16)
armor_shield(1608, 1690, 104, 18)
armor_chest(1440, 1700, 84, -18)
# upper-left remains
paste_skeleton(430, 380, 210, 96)
armor_helmet(512, 448, 58, 40)
armor_sword(360, 470, 130, -30)

# scattered bones
for bx, by, spread in [(500, 1600, 140), (1530, 1640, 130), (440, 420, 100)]:
    for _ in range(5):
        x0 = bx + random.uniform(-spread, spread)
        y0 = by + random.uniform(-spread, spread)
        ang = random.uniform(0, math.tau)
        ln = random.uniform(26, 58)
        bone_seg(d, x0, y0, x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln, 3)

# ------------------------------------------------------- skull torches
def torch_skull(cx, cy):
    # broad warm glow around the skull
    glow = layer()
    gl = ImageDraw.Draw(glow)
    for rr, a in [(62, 130), (96, 100), (140, 62)]:
        gl.ellipse([cx - rr, cy - rr * 1.25, cx + rr, cy + rr * 0.9],
                   fill=(255, 104, 20, a))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(26)))

    # scorched stone around the base
    soot = layer()
    sd3 = ImageDraw.Draw(soot)
    sd3.ellipse([cx - 66, cy - 58, cx + 66, cy + 58], fill=(8, 7, 6, 100))
    img.alpha_composite(soot.filter(ImageFilter.GaussianBlur(14)))

    base = layer()
    bdd = ImageDraw.Draw(base)
    bdd.ellipse([cx - 50, cy - 26, cx + 50, cy + 42], fill=(30, 27, 24, 215))
    bdd.ellipse([cx - 44, cy - 30, cx + 44, cy + 32], fill=(48, 42, 36, 230))
    img.alpha_composite(base.filter(ImageFilter.GaussianBlur(2)))

    paste_skull(cx, cy, 106, 0, tint=(178, 166, 138), aged=True)

    # heat bloom on the cranium
    heat = layer()
    hd = ImageDraw.Draw(heat)
    hd.ellipse([cx - 44, cy - 54, cx + 44, cy + 4], fill=(255, 104, 18, 95))
    hd.ellipse([cx - 26, cy - 48, cx + 26, cy - 4], fill=(255, 170, 58, 90))
    img.alpha_composite(heat.filter(ImageFilter.GaussianBlur(9)))

    # white-hot eye sockets
    eye = layer()
    ed = ImageDraw.Draw(eye)
    for ex in (cx - 16, cx + 16):
        ed.ellipse([ex - 11, cy - 20, ex + 11, cy + 1], fill=(238, 118, 20, 220))
        ed.ellipse([ex - 6, cy - 16, ex + 6, cy - 2], fill=(255, 214, 120, 245))
        ed.ellipse([ex - 3, cy - 12, ex + 3, cy - 4], fill=(255, 250, 220, 255))
    img.alpha_composite(eye.filter(ImageFilter.GaussianBlur(2)))

    # rising embers
    for _ in range(9):
        ex = cx + random.uniform(-46, 46)
        ey = cy - random.uniform(78, 138)
        rr = random.uniform(3.0, 6.5)
        spark = layer()
        spd = ImageDraw.Draw(spark)
        spd.ellipse([ex - rr, ey - rr, ex + rr, ey + rr], fill=(255, 152, 44, 220))
        img.alpha_composite(spark.filter(ImageFilter.GaussianBlur(1.5)))


for tx, ty in [(160, 160), (1840, 160), (160, 1840), (1840, 1840)]:
    torch_skull(tx, ty)

# ---------------------------------------------------------------- vignette
vig = Image.new("L", (W, H), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([-320, -320, W + 320, H + 320], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(260))
dark = Image.new("RGBA", (W, H), (0, 0, 0, 80))
dark.putalpha(ImageChops.subtract(Image.new("L", (W, H), 80), vig))
img.alpha_composite(dark)

# ------------------------------------------------------------- pixel-art pass
PIXEL = 8
small = img.convert("RGB").resize((W // PIXEL, H // PIXEL), Image.BOX)
small = small.quantize(colors=32, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
img = small.resize((W, H), Image.NEAREST).convert("RGBA")

# re-apply the worn glyphs and their purple glow after quantization so they
# keep their colour and stay crisp at the art's pixel resolution
glyph_px = glyph_overlay.resize((W // PIXEL, H // PIXEL), Image.BOX)
glyph_px = glyph_px.resize((W, H), Image.NEAREST)
img.alpha_composite(glyph_px)

# --------------------------------------- vivid pixel flames (drawn after quantize)
d = ImageDraw.Draw(img)


def px_snap(v):
    return int(round(v / PIXEL) * PIXEL)


def px_block(x0, y0, x1, y1, col):
    x0 = px_snap(x0)
    x1 = max(x0 + PIXEL, px_snap(x1))
    y0 = px_snap(y0)
    y1 = max(y0 + PIXEL, px_snap(y1))
    d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=col)


def pixel_tongue(cx, base_y, height, max_half, seed):
    steps = max(3, int(height / PIXEL))
    for i in range(steps):
        u = i / (steps - 1)
        y = base_y - i * PIXEL
        hw = max(PIXEL, px_snap(max_half * (1 - u) ** 0.6))
        wob = px_snap(math.sin(u * 5.2 + seed) * max_half * 0.35 * u)
        x = cx + wob
        px_block(x - hw, y, x + hw, y + PIXEL, (196, 58, 6, 255))
        if hw >= PIXEL * 2:
            px_block(x - hw * 0.70, y, x + hw * 0.70, y + PIXEL, (242, 112, 14, 255))
        if hw >= PIXEL * 3 and u < 0.82:
            px_block(x - hw * 0.40, y, x + hw * 0.40, y + PIXEL, (255, 188, 58, 255))
        if hw >= PIXEL * 3 and u < 0.55:
            px_block(x - hw * 0.18, y, x + hw * 0.18, y + PIXEL, (255, 240, 190, 255))


def pixel_torch(cx, cy):
    # side tongues first, main tongue in front
    pixel_tongue(cx - 23, cy - 34, 66, 18, 1.7)
    pixel_tongue(cx + 21, cy - 32, 74, 18, 3.1)
    pixel_tongue(cx, cy - 42, 94, 28, 0.4)

    # glowing eye sockets
    for ex in (cx - 16, cx + 16):
        px_block(ex - 10, cy - 16, ex + 10, cy + 4, (234, 104, 14, 255))
        px_block(ex - 5, cy - 12, ex + 5, cy, (255, 214, 112, 255))
        px_block(ex - 2, cy - 9, ex + 2, cy - 3, (255, 248, 206, 255))

    # embers drifting up
    for _ in range(4):
        ex = px_snap(cx + random.uniform(-40, 40))
        ey = px_snap(cy - random.uniform(84, 124))
        d.rectangle([ex, ey, ex + PIXEL - 1, ey + PIXEL - 1], fill=(255, 168, 52, 255))


for tx, ty in [(160, 160), (1840, 160), (160, 1840), (1840, 1840)]:
    pixel_torch(tx, ty)

out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "arena_map.png")
img.convert("RGB").save(out_path)
print("saved", out_path, img.size)
