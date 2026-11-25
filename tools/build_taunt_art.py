"""Cuts the supplied goblin taunt sheets into game-ready sprite sheets.

Run from the project root:  python tools/build_taunt_art.py
Input : assets/goblin_sprites/wave_1_taunt.webp, wave_2_taunt.webp, wave_3_taunt.webp
Output: assets/goblin_sprites/taunt_1_sheet.png / taunt_1_frames.tres (and 2, 3)

Frames are only cropped and scaled, never redrawn, and keep the order they have on the
sheet (left to right, top to bottom). Each sheet is scaled so the goblin's body (head top
to feet) matches the same wave's walking/fighting art, and anchored at the feet so
swapping between the two sets of frames does not make the goblin jump.
"""
import re
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

G = "assets/goblin_sprites/"


def body_height(rgba: np.ndarray) -> float:
	"""Head top (highest green skin pixel) to feet (lowest opaque pixel)."""
	a = rgba[..., 3] > 128
	r, g, b = (rgba[..., i].astype(int) for i in range(3))
	skin = a & (g > r + 15) & (g > b + 25)
	rows = np.where(a.any(axis=1))[0]
	lab, n = ndi.label(skin)
	sizes = ndi.sum(skin, lab, range(1, n + 1))
	head = lab == (int(np.argmax(sizes)) + 1) # the biggest green patch is the face
	top = np.where(head.any(axis=1))[0][0]
	return float(rows[-1] - top)


def existing_height(sheet: str, box: tuple) -> float:
	im = np.array(Image.open(G + sheet).convert("RGBA"))
	x, y, w, h = box
	return body_height(im[y:y + h, x:x + w])


def frames_by_components(a: np.ndarray, dil: int, min_area: int) -> list:
	m = a[..., 3] > 200
	lab, _ = ndi.label(ndi.binary_dilation(m, iterations=dil))
	found = []
	for i, sl in enumerate(ndi.find_objects(lab)):
		sel = m & (lab == i + 1)
		if sel.sum() >= min_area:
			found.append((sl[0].start, sl[1].start, sel))
	# row bands first (rows are > 150 px apart), then left to right
	found.sort(key=lambda f: (f[0] // 250, f[1]))
	return [f[2] for f in found]


def frames_by_cores(a: np.ndarray, cores: list) -> list:
	"""For sheets whose frames touch: every opaque pixel joins the nearest frame body."""
	m = ndi.binary_opening(a[..., 3] > 240, iterations=2)
	lab, _ = ndi.label(m)
	core = np.zeros(m.shape, int)
	for i, (x0, y0, x1, y1) in enumerate(cores):
		core[int(y0 * 1.678):int(y1 * 1.678), int(x0 * 1.678):int(x1 * 1.678)] = i + 1
	core[~m] = 0
	_, (iy, ix) = ndi.distance_transform_edt(core == 0, return_indices=True)
	owner = core[iy, ix]
	frames = []
	for i in range(len(cores)):
		own = m & (owner == i + 1)
		lab2, n2 = ndi.label(own)
		sizes = ndi.sum(own, lab2, range(1, n2 + 1))
		keep = [k + 1 for k, sz in enumerate(sizes) if sz >= 0.15 * sizes.max()] # drops neighbours' stray bits
		frames.append(np.isin(lab2, keep))
	return frames


def to_image(a: np.ndarray, sel: np.ndarray) -> Image.Image:
	out = a.copy()
	out[..., 3] = np.where(sel, 255, 0)
	im = Image.fromarray(out.astype(np.uint8))
	return im.crop(im.getbbox())


def feet_x(im: Image.Image) -> int:
	"""Horizontal centre of the lowest strip of the frame (the feet)."""
	al = np.array(im)[..., 3] > 0
	h = al.shape[0]
	strip = al[int(h * 0.9):]
	return int(np.where(strip.any(axis=0))[0].mean())


def build(index: int, frames: list, target_body: float, clips: dict, fixed_scale: float = 0.0) -> None:
	arrays = [np.array(f) for f in frames]
	heights = [body_height(x) for x in arrays]
	scale = fixed_scale if fixed_scale > 0.0 else target_body / float(np.median(heights))
	small = [f.resize((max(1, round(f.size[0] * scale / 2)), max(1, round(f.size[1] * scale / 2))), Image.LANCZOS) for f in frames]
	anchors = [round(feet_x(f) * scale / 2) for f in frames]
	pix = np.concatenate([np.array(s)[..., :3][np.array(s)[..., 3] > 128] for s in small])
	pal = Image.fromarray(pix.reshape(-1, 1, 3).astype(np.uint8)).quantize(64, method=Image.MEDIANCUT)
	left = max(anchors)
	right = max(s.size[0] - a for s, a in zip(small, anchors))
	cw = (left + right) * 2 + 8
	ch = max(s.size[1] for s in small) * 2 + 8
	sheet = Image.new("RGBA", (cw * len(small), ch), (0, 0, 0, 0))
	for i, (s, anchor) in enumerate(zip(small, anchors)):
		alpha = np.array(s)[..., 3] > 128
		q = np.array(s.convert("RGB").quantize(palette=pal, dither=Image.NONE).convert("RGB"))
		out = Image.fromarray(np.dstack([q, (alpha * 255).astype(np.uint8)]).astype(np.uint8)).resize((s.size[0] * 2, s.size[1] * 2), Image.NEAREST)
		x = i * cw + cw // 2 - anchor * 2
		sheet.paste(out, (x, ch - 4 - out.size[1]), out)
	sheet.save(f"{G}taunt_{index}_sheet.png")
	tres = ['[gd_resource type="SpriteFrames" format=3]', "",
			f'[ext_resource type="Texture2D" path="res://{G}taunt_{index}_sheet.png" id="1_sheet"]', ""]
	for i in range(len(small)):
		tres += [f'[sub_resource type="AtlasTexture" id="AtlasTexture_{i}"]', 'atlas = ExtResource("1_sheet")',
				 f"region = Rect2({i * cw}, 0, {cw}, {ch})", ""]
	entries = []
	for name, (a, b) in clips.items():
		fr = ", ".join('{"duration": 1.0, "texture": SubResource("AtlasTexture_%d")}' % i for i in range(a, b))
		entries.append('{\n"frames": [%s],\n"loop": false,\n"name": &"%s",\n"speed": 6.0\n}' % (fr, name))
	tres += ["[resource]", "animations = [" + ", ".join(entries) + "]", ""]
	open(f"{G}taunt_{index}_frames.tres", "w").write("\n".join(tres))
	print(f"wave {index}: {len(small)} frames, cell {cw}x{ch}, scale {scale:.3f}, sprite position.y should be {16 - ch / 2}")


def clips_for(n: int) -> dict:
	"""The whole sheet in order, plus its two halves, so the mocking is not always identical."""
	half = n // 2
	return {"taunt_full": (0, n), "taunt_first": (0, half), "taunt_second": (half, n)}


if __name__ == "__main__":
	# target body heights come from each wave's existing art
	h1 = existing_height("goblin_sheet.png", (0, 384, 192, 192))      # wave 1 idle-stance frame
	h2 = existing_height("spear_sheet.png", (136, 0, 136, 172))        # wave 2 idle frame
	h3 = existing_height("hammer_sheet.png", (0, 0, 178, 216))         # wave 3 idle frame
	print("target body heights", h1, h2, h3)

	a1 = np.array(Image.open(G + "wave_1_taunt.webp").convert("RGBA"))
	f1 = [to_image(a1, s) for s in frames_by_components(a1, 3, 3000)]
	build(1, f1, h1, clips_for(len(f1)))

	a2 = np.array(Image.open(G + "wave_2_taunt.webp").convert("RGBA"))
	f2 = [to_image(a2, s) for s in frames_by_components(a2, 5, 3000)]
	build(2, f2, h2, clips_for(len(f2)))

	a3 = np.array(Image.open(G + "wave_3_taunt.webp").convert("RGBA"))
	cores = [(15, 100, 165, 290), (255, 120, 390, 290), (430, 120, 575, 285), (590, 100, 710, 285),
			 (710, 130, 840, 290), (855, 130, 990, 290), (25, 320, 190, 480), (215, 330, 370, 480),
			 (420, 340, 520, 480), (640, 335, 810, 475), (850, 320, 985, 480)]
	f3 = [to_image(a3, s) for s in frames_by_cores(a3, cores)]
	build(3, f3, h3, clips_for(len(f3)), 0.45) # body is ~320 px tall on the sheet: 0.45 gives ~145 px, like the hammer goblin's idle
