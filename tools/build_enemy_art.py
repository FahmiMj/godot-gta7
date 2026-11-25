"""Cuts the supplied Wave 2 / Wave 3 goblin art and the HP-bar art into game-ready files.

Run from the project root:  python tools/build_enemy_art.py
Nothing is redrawn: frames are cropped from the supplied images, the black background is
keyed out, and each frame is scaled with the same pipeline the Wave 1 sheet used
(downscale -> shared 64-colour palette -> 2x nearest).
Outputs (all in assets/goblin_sprites/ and assets/ghoul_sprites/):
  spear_sheet.png + spear_frames.tres   hammer_sheet.png + hammer_frames.tres
  hp_goblin_*.png / hp_ghoul_*.png      (bar frame, fill and icon)
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

G = "assets/goblin_sprites/"
U = "assets/ghoul_sprites/"


def key_black(img: Image.Image, thr: int) -> np.ndarray:
	"""RGBA array with the background (dark pixels connected to the border) made transparent."""
	a = np.array(img.convert("RGBA"))
	dark = a[..., :3].max(axis=2) < thr
	lab, _ = ndi.label(dark)
	edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
	bg = np.isin(lab, list(edge))
	a[..., 3] = np.where(bg, 0, 255)
	return a


def drop_specks(a: np.ndarray, min_area: int) -> np.ndarray:
	"""Removes small disconnected bits (the sheet's white swoosh lines and dust puffs)."""
	lab, n = ndi.label(ndi.binary_dilation(a[..., 3] > 0, iterations=3))
	keep = np.zeros(a.shape[:2], bool)
	for i in range(1, n + 1):
		m = lab == i
		if (a[..., 3][m] > 0).sum() >= min_area:
			keep |= m
	a = a.copy()
	a[..., 3] = np.where(keep & (a[..., 3] > 0), 255, 0)
	return a


def crop_frame(a: np.ndarray, box: tuple, min_area: int = 900, thr_big: bool = True) -> Image.Image:
	x0, y0, x1, y1 = box
	sub = drop_specks(a[y0:y1, x0:x1], min_area)
	im = Image.fromarray(sub)
	bb = im.getbbox()
	return im.crop(bb)


def build_sheet(frames: dict, net_scale: float, name: str, anims: dict, speeds: dict, loops: dict, mult: dict = {}) -> None:
	"""frames: {key: RGBA image}. Scales, shares a palette, lays out in equal cells bottom-centre."""
	small = {}
	for k, im in frames.items():
		w, h = im.size
		small[k] = im.resize((max(1, round(w * net_scale * mult.get(k, 1.0) / 2)), max(1, round(h * net_scale * mult.get(k, 1.0) / 2))), Image.LANCZOS)
	# shared palette over all opaque pixels
	pix = np.concatenate([np.array(s)[..., :3][np.array(s)[..., 3] > 128] for s in small.values()])
	pal_img = Image.fromarray(pix.reshape(-1, 1, 3).astype(np.uint8)).quantize(64, method=Image.MEDIANCUT)
	cell_w = max(s.size[0] for s in small.values()) * 2 + 8
	cell_h = max(s.size[1] for s in small.values()) * 2 + 8
	keys = list(small)
	sheet = Image.new("RGBA", (cell_w * len(keys), cell_h), (0, 0, 0, 0))
	for i, k in enumerate(keys):
		s = small[k]
		alpha = np.array(s)[..., 3] > 128
		q = np.array(s.convert("RGB").quantize(palette=pal_img, dither=Image.NONE).convert("RGB"))
		out = Image.fromarray(np.dstack([q, (alpha * 255).astype(np.uint8)]).astype(np.uint8))
		out = out.resize((out.size[0] * 2, out.size[1] * 2), Image.NEAREST)
		# bottom-centre anchor: feet at the cell bottom
		sheet.paste(out, (i * cell_w + (cell_w - out.size[0]) // 2, cell_h - 4 - out.size[1]), out)
	sheet.save(f"{G}{name}_sheet.png")

	tres = ['[gd_resource type="SpriteFrames" format=3]', "",
			f'[ext_resource type="Texture2D" path="res://{G}{name}_sheet.png" id="1_sheet"]', ""]
	for i, k in enumerate(keys):
		tres += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{k}"]', 'atlas = ExtResource("1_sheet")',
				 f"region = Rect2({i * cell_w}, 0, {cell_w}, {cell_h})", ""]
	entries = []
	for anim, ks in anims.items():
		fr = ", ".join('{"duration": 1.0, "texture": SubResource("AtlasTexture_%s")}' % k for k in ks)
		entries.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
					   % (fr, "true" if loops[anim] else "false", anim, speeds[anim]))
	tres += ["[resource]", "animations = [" + ", ".join(entries) + "]", ""]
	open(f"{G}{name}_frames.tres", "w").write("\n".join(tres))
	print(name, "cell", cell_w, cell_h, "frames", keys)


def spear() -> None:
	a = key_black(Image.open(G + "wave_2.webp"), 30)
	cw, ch = 1376 // 6, 752 // 2
	frames = {}
	for idx in (2, 5, 9, 11, 7, 8):
		r, c = divmod(idx, 6)
		frames[f"f{idx}"] = crop_frame(a, (c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
	idle = ["f5", "f11", "f9", "f2"]
	anims = {"idle": idle, "walk_side": idle, "walk_up": idle, "walk_down": idle,
			 "prep": ["f5", "f8"], "throw": ["f7"], "hurt": ["f11"], "death": ["f11"], "attack": ["f7"]}
	speeds = {k: 1.0 for k in anims}
	speeds.update({"idle": 5.0, "walk_side": 8.0, "walk_up": 8.0, "walk_down": 8.0, "prep": 5.0})
	build_sheet(frames, 0.56, "spear", anims, speeds, {k: k in ("idle", "walk_side", "walk_up", "walk_down") for k in anims})


def hammer() -> None:
	a = key_black(Image.open(G + "wavee_3.jpg"), 45)
	boxes = {
		"idle": (842, 140, 1010, 372),   # carrying the hammer
		"windup": (0, 15, 228, 372),     # hammer raised overhead
		"jump": (455, 350, 690, 605),    # tucked, hammer raised
		"slam": (8, 385, 238, 608),      # crouched, hammer down
		"recover": (737, 385, 990, 608),  # hammer lowered, shield up
	}
	frames = {k: crop_frame(a, b, 1500) for k, b in boxes.items()}
	anims = {"idle": ["idle"], "walk_side": ["idle"], "walk_up": ["idle"], "walk_down": ["idle"],
			 "windup": ["windup"], "jump": ["jump"], "slam": ["slam"], "recover": ["recover"],
			 "hurt": ["idle"], "death": ["idle"], "attack": ["slam"]}
	speeds = {k: 1.0 for k in anims}
	build_sheet(frames, 0.72, "hammer", anims, speeds, {k: k in ("idle", "walk_side", "walk_up", "walk_down") for k in anims}, {"windup": 0.85})


def hp_bar(src: str, prefix: str, dst: str, fill_dark: bool) -> None:
	a = np.array(Image.open(src).convert("RGB")).astype(int)
	m = a.max(axis=2) > 40
	cols = np.where(m.any(axis=0))[0]
	rows = np.where(m.any(axis=1))[0]
	gap = np.where(np.diff(cols) > 5)[0][0]
	icon_x = (cols[0], cols[gap])
	bar_x = (cols[gap + 1], cols[-1])
	y0, y1 = rows[0], rows[-1]
	mid = (y0 + y1) // 2
	line = a[mid]
	# fill = saturated colour (r-g or b-g large); interior ends where the empty (dark) tint ends
	sat = (np.abs(line[:, 0] - line[:, 1]) > 120) | (np.abs(line[:, 2] - line[:, 1]) > 120)
	xs = np.where(sat[bar_x[0]:bar_x[1]])[0] + bar_x[0]
	f0 = xs[0]
	dark = (line[:, :3].max(axis=1) < 75) & ((np.abs(line[:, 0] - line[:, 1]) > 15) | (np.abs(line[:, 2] - line[:, 1]) > 15))
	e1 = np.where(dark[f0:bar_x[1] - 10])[0].max() + f0
	fill_col = f0 + 120
	empty_col = e1 - 120
	sample = a[:, fill_col]
	interior_rows = [y for y in range(y0, y1 + 1) if abs(sample[y, 0] - sample[y, 1]) > 60 or abs(sample[y, 2] - sample[y, 1]) > 60 or (sample[y].max() > 60 and sample[y].max() < 255 and abs(sample[y, 0] - sample[y, 2]) > 20)]
	r0, r1 = min(interior_rows), max(interior_rows)
	bar = a[y0:y1 + 1, bar_x[0]:bar_x[1] + 1].copy()
	under = bar.copy()
	prog = np.zeros((bar.shape[0], bar.shape[1], 4), int)
	for x in range(f0, e1 + 1):
		bx = x - bar_x[0]
		under[:, bx] = a[y0:y1 + 1, empty_col]
		prog[r0 - y0:r1 - y0 + 1, bx, :3] = a[r0:r1 + 1, fill_col]
		prog[r0 - y0:r1 - y0 + 1, bx, 3] = 255
	scale = 96.0 / bar.shape[1]
	size = (96, max(4, round(bar.shape[0] * scale)))
	Image.fromarray(under.astype(np.uint8)).resize(size, Image.BOX).save(f"{dst}{prefix}_under.png")
	Image.fromarray(prog.astype(np.uint8), "RGBA").resize(size, Image.BOX).save(f"{dst}{prefix}_fill.png")
	icon = Image.open(src).convert("RGB").crop((icon_x[0], y0, icon_x[1] + 1, y1 + 1))
	icon_a = np.array(icon)
	alpha = (icon_a.max(axis=2) > 40) * 255
	icon = Image.fromarray(np.dstack([icon_a, alpha]).astype(np.uint8))
	s = size[1] / icon.size[1] * 1.0
	icon.resize((max(1, round(icon.size[0] * s)), size[1]), Image.BOX).save(f"{dst}{prefix}_icon.png")
	print(prefix, "bar", size, "fill cols", f0, e1)


if __name__ == "__main__":
	spear()
	hammer()
	hp_bar(G + "hp_bar.webp", "hp_goblin", G, False)
	hp_bar(U + "hp_bar.webp", "hp_ghoul", U, True)
