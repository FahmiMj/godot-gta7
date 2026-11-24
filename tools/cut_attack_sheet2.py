#!/usr/bin/env python3
"""Cut the new directional attack sheet into per-direction strips.

Source: one row per direction (Down / Up / Left / Right / Special), each row
holding a rounded label badge followed by five frames. The artwork ignores the
sheet's own 200 px cell grid (capes and slash arcs bleed over it), so frames are
found by splitting every row at the empty columns between poses.

Output frames are 224x192 with the character's body centred horizontally and
its feet on the same baseline as the walk sprites, so the same
AnimatedSprite2D offset works for every animation.
"""
from PIL import Image

SRC = "/home/fahmi/Documents/godot non git/Gemini_Generated_Image_owvzxeowvzxeowvz-Photoroom.png"
OUT = "/home/fahmi/Documents/godot/godot-gta7/assets/sprites/attacks"

CELL_W, CELL_H = 224, 192
BODY_CX = CELL_W // 2      # body centre inside the cell
FEET_Y = CELL_H - 3        # baseline, matches the walk sprites
TARGET_BODY_H = 169        # walk sprite body height in player_sheet.png

# row index in the sheet -> direction written to disk. The sheet's own "Left
# Attack" row is drawn mirrored, so both sideways attacks are cut from the
# "Right Attack" row and the left one is flipped. The special row is skipped.
ROWS = {"down": 0, "up": 1, "right": 3}

# The 5th pose is a duplicate of the 1st, so only the first four are cut and
# the last frame of every animation reuses the opening pose.
FRAME_COLUMNS = 4


def load(path):
    return Image.open(path).convert("RGBA")


def body_mask(r, g, b):
    """The character body is dark and low-saturation; slash effects are bright
    red/white, so they never contribute to the body box."""
    hi = max(r, g, b)
    return hi < 120 and (hi - min(r, g, b)) < 70


def row_bands(im):
    """Split the sheet at fully transparent horizontal strips."""
    px = im.load()
    cover = [sum(1 for x in range(0, im.width, 2) if px[x, y][3] > 20) for y in range(im.height)]
    bands, start = [], None
    for y, n in enumerate(cover):
        if n and start is None:
            start = y
        elif not n and start is not None:
            bands.append((start, y - 1))
            start = None
    if start is not None:
        bands.append((start, im.height - 1))
    return bands


def frame_spans(im, y0, y1, count=5):
    """Column spans of the frames in one row, dropping the label badge."""
    px = im.load()
    cover = []
    for x in range(im.width):
        n = 0
        for y in range(y0, y1 + 1):
            if px[x, y][3] > 20:
                n += 1
        cover.append(n)

    spans, start = [], None
    for x, n in enumerate(cover):
        if n and start is None:
            start = x
        elif not n and start is not None:
            spans.append((start, x - 1))
            start = None
    if start is not None:
        spans.append((start, im.width - 1))

    # merge spans separated by only a hair (anti-aliasing / floating sparks)
    merged = [spans[0]]
    for a, b in spans[1:]:
        if a - merged[-1][1] <= 6:
            merged[-1] = (merged[-1][0], b)
        else:
            merged.append((a, b))

    # the first span is always the label badge
    frames = merged[1:]
    assert len(frames) == count, f"expected {count} frames, got {len(frames)}: {merged}"
    return frames


def body_box(crop):
    w, h = crop.size
    px = crop.load()
    box = None
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 60 and body_mask(r, g, b):
                box = [x, y, x, y] if box is None else [
                    min(box[0], x), min(box[1], y), max(box[2], x), max(box[3], y)
                ]
    return box


def head_anchor(crop, box):
    """Horizontal centre of the hair, taken from the top quarter of the body.

    Using the whole body box would let a long cape (or a ground slam) drag the
    character sideways from frame to frame; the hair is symmetric and always
    present, so the character stays put.
    """
    if not box:
        return crop.width / 2
    w, h = crop.size
    px = crop.load()
    top = box[1]
    band_end = top + max(4, (box[3] - box[1]) // 4)
    xs = []
    for y in range(top, min(h, band_end + 1)):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 60 and body_mask(r, g, b):
                xs.append(x)
    return sum(xs) / len(xs) if xs else (box[0] + box[2]) / 2


def main():
    im = load(SRC)
    bands = row_bands(im)
    assert len(bands) >= 4, bands

    crops = {}   # direction -> list of (image, body box)
    for name, row in ROWS.items():
        y0, y1 = bands[row]
        spans = frame_spans(im, y0, y1)
        spans = spans[:FRAME_COLUMNS]
        crops[name] = []
        for a, b in spans:
            crop = im.crop((a, y0, b + 1, y1 + 1))
            bb = crop.getbbox()
            crop = crop.crop(bb)
            crops[name].append((crop, body_box(crop)))
        # closing frame = opening pose
        crops[name].append(crops[name][0])
        print(name, "row", row, "->", len(crops[name]), "frames")

    heights = sorted(b[3] - b[1] + 1 for frames in crops.values() for _, b in frames if b)
    scale = TARGET_BODY_H / heights[len(heights) // 2]
    print("median body height", heights[len(heights) // 2], "scale", round(scale, 3))

    for name, frames in crops.items():
        out = Image.new("RGBA", (CELL_W * len(frames), CELL_H), (0, 0, 0, 0))
        for i, (crop, body) in enumerate(frames):
            nw = max(1, round(crop.width * scale))
            nh = max(1, round(crop.height * scale))
            f = crop.resize((nw, nh), Image.LANCZOS)
            if body:
                bcx = head_anchor(crop, body) * scale
                by = body[3] * scale
                ox = round(BODY_CX - bcx)
                oy = round(FEET_Y - by)
            else:
                ox = (CELL_W - nw) // 2
                oy = FEET_Y - nh
            out.alpha_composite(f, (i * CELL_W + ox, oy))
        path = f"{OUT}/attack_{name}.png"
        out.save(path)
        print("wrote", path, out.size)

    # the left attack is the right attack mirrored, frame by frame, so the
    # character keeps the exact same position in the cell
    right = Image.open(f"{OUT}/attack_right.png").convert("RGBA")
    left = Image.new("RGBA", right.size, (0, 0, 0, 0))
    for i in range(right.width // CELL_W):
        cell = right.crop((i * CELL_W, 0, (i + 1) * CELL_W, CELL_H))
        left.alpha_composite(cell.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (i * CELL_W, 0))
    left.save(f"{OUT}/attack_left.png")
    print("wrote", f"{OUT}/attack_left.png", left.size, "(mirrored right)")


if __name__ == "__main__":
    main()
