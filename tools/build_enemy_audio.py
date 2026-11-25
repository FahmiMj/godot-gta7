"""Synthesises the new enemy sound effects (no recordings were supplied for them).
Run from the project root:  python tools/build_enemy_audio.py
Writes 16-bit mono 22.05 kHz wav files into assets/audio/.
"""
import wave
import numpy as np

RATE = 22050
rng = np.random.default_rng(7)


def t(sec: float) -> np.ndarray:
	return np.linspace(0, sec, int(RATE * sec), endpoint=False)


def save(name: str, x: np.ndarray, gain: float = 0.8) -> None:
	x = x / max(1e-6, np.abs(x).max()) * gain
	with wave.open(f"assets/audio/{name}.wav", "wb") as f:
		f.setnchannels(1)
		f.setsampwidth(2)
		f.setframerate(RATE)
		f.writeframes((x * 32767).astype(np.int16).tobytes())
	print(name, len(x) / RATE)


def lowpass(x: np.ndarray, k: int) -> np.ndarray:
	return np.convolve(x, np.ones(k) / k, mode="same")


def wail(sec: float, f0: float, f1: float, vib: float, attack: float = 0.25) -> np.ndarray:
	"""A ghostly voice: gliding pitch with vibrato, a few harmonics and breath noise."""
	tt = t(sec)
	freq = np.linspace(f0, f1, len(tt)) * (1 + 0.03 * np.sin(2 * np.pi * vib * tt))
	ph = 2 * np.pi * np.cumsum(freq) / RATE
	x = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph + 1)
	x += 0.35 * lowpass(rng.standard_normal(len(tt)), 6)
	env = np.minimum(tt / (sec * attack), 1) * np.minimum((sec - tt) / (sec * 0.45), 1)
	return x * np.clip(env, 0, 1)


# idle / ambient presence: slow, quiet, rising moan
save("ghoul_ambient", wail(1.8, 150, 210, 4.5, 0.5) * 0.7)
# hurt: short startled warble
save("ghoul_hurt", wail(0.45, 420, 240, 14, 0.08))
# death: long falling wail that fades out
save("ghoul_death", wail(1.5, 380, 70, 6, 0.1))
# teleport: shimmering rising sweep + airy burst
tt = t(0.7)
sweep = np.sin(2 * np.pi * np.cumsum(np.linspace(300, 1500, len(tt))) / RATE) * np.hanning(len(tt))
air = lowpass(rng.standard_normal(len(tt)), 3) * np.hanning(len(tt)) * 0.6
save("ghoul_teleport", sweep * 0.6 + air)
# spear throw: quick airy whoosh
tt = t(0.32)
w = rng.standard_normal(len(tt))
w = lowpass(w, 4) - lowpass(w, 40)
save("spear_throw", w * np.sin(np.pi * tt / 0.32) ** 1.5)
# hammer slam: sub boom with a crack
tt = t(0.7)
boom = np.sin(2 * np.pi * np.cumsum(np.linspace(110, 38, len(tt))) / RATE) * np.exp(-tt * 6)
crack = lowpass(rng.standard_normal(len(tt)), 5) * np.exp(-tt * 30)
save("hammer_slam", boom + crack * 0.8)
# hammer jump: heavy whoosh
tt = t(0.4)
w = lowpass(rng.standard_normal(len(tt)), 12) * np.sin(np.pi * tt / 0.4)
save("hammer_jump", w)
