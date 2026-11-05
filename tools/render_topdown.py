#!/usr/bin/env python3
"""Рендер спрайтов «вид сверху» из 3D-моделей Kenney Space Kit.

В паке есть только виды сбоку и в изометрии, а вертикальному шутеру нужен
вид сверху. Модели low-poly с однотонными материалами (Kd в .mtl), поэтому
хватает простого растеризатора: плоское освещение, z-буфер, суперсэмплинг.

Модели читаются прямо из архива, результат — PNG с прозрачным фоном.

    python3 tools/render_topdown.py                 # все спрайты из SPRITES
    python3 tools/render_topdown.py ship_swift      # только указанные

Нужны numpy и Pillow.
"""
import io
import sys
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "Assets" / "kenney_space-kit.zip"
OUT_DIR = ROOT / "art" / "sprites"
OBJ_DIR = "Models/OBJ format/"

SUPERSAMPLE = 4
# Свет сверху-слева-спереди. Низкий ambient + сильный diffuse дают контраст
# между гранями — модель читается объёмной, а не плоской.
LIGHT_DIR = np.array([-0.5, 1.0, -0.6])
AMBIENT = 0.32
DIFFUSE = 0.8
# Блики (Blinn-Phong): насколько ярко и насколько узко.
SPECULAR = 0.35
SHININESS = 24
# Затемнение по высоте: самые низкие части модели темнее на столько.
DEPTH_DARKEN = 0.4
# Градиент освещения по всей модели (от верхнего левого угла к нижнему правому):
# большие плоские грани перестают быть однотонными.
LIGHT_GRADIENT = 0.22
# Цвет тонкого контура вокруг кораблей (outline=True).
OUTLINE_COLOR = (0.07, 0.05, 0.09)

# Палитры для перекраски оранжевых деталей (материал metalRed).
PLAYER_FALCON = {"metalRed": (0.95, 0.3, 0.25)}
PLAYER_SWIFT = {"metalRed": (0.25, 0.65, 1.0)}
PLAYER_BASTION = {"metalRed": (0.5, 0.8, 0.3)}
ENEMY = {"metalRed": (0.75, 0.25, 0.65), "metal": (0.6, 0.58, 0.66)}
BOSS = {"metalRed": (0.85, 0.2, 0.3), "metal": (0.5, 0.48, 0.55), "metalDark": (0.38, 0.36, 0.44)}

# Имя спрайта → модель, размер большей стороны (px), поворот на экране
# (0 — нос модели вниз), наклон камеры вперёд (немного показывает борта)
# и перекраска материалов.
SPRITES = {
    # корабли игрока — нос вверх
    "ship_falcon": dict(model="craft_speederA", size=84, rotation=180, tilt=30, outline=True, recolor=PLAYER_FALCON),
    "ship_swift": dict(model="craft_racer", size=86, rotation=180, tilt=30, outline=True, recolor=PLAYER_SWIFT),
    "ship_bastion": dict(model="craft_cargoA", size=80, rotation=180, tilt=30, outline=True, recolor=PLAYER_BASTION),
    # враги — нос вниз, летят на игрока
    "enemy_fighter": dict(model="craft_speederB", size=64, rotation=0, tilt=30, outline=True, recolor=ENEMY),
    "enemy_gunship": dict(model="craft_miner", size=88, rotation=0, tilt=30, outline=True, recolor=ENEMY),
    "boss": dict(model="craft_cargoB", size=200, rotation=0, tilt=30, outline=True, recolor=BOSS),
    # наземные враги — строго сверху (в игре поворачиваются целиком).
    # Танк — нос вниз. Турель — две части: основание и вращающаяся башня;
    # axis=R — квадратный кадр ±R вокруг оси модели, чтобы центр картинки
    # совпадал с осью вращения и башня садилась ровно на основание.
    "ground_tank": dict(model="rover", size=50, rotation=0, tilt=0, outline=True, recolor=ENEMY),
    "ground_turret_base": dict(model="turret_double", size=84, tilt=0, outline=True, recolor=ENEMY, part=("below", 0.2), axis=0.5),
    "ground_turret_head": dict(model="turret_double", size=84, tilt=0, outline=True, recolor=ENEMY, part=("above", 0.2), axis=0.5),
}

# Декор поверхности планет. Для каждого биома — свой набор с перекраской
# материалов скал (rock, rockDark, rockTrack) и кристаллов (crystal).
# Марс — исходные цвета пака, файлы decor_*.png; остальные — decor_<биом>_*.png.
DECOR = {
    "crater": dict(model="crater", size=150),
    "crater_large": dict(model="craterLarge", size=260),
    "rock": dict(model="rock", size=70),
    "rock_large_a": dict(model="rock_largeA", size=120),
    "rock_large_b": dict(model="rock_largeB", size=120),
    "rocks_small_a": dict(model="rocks_smallA", size=90),
    "rocks_small_b": dict(model="rocks_smallB", size=90),
    "crystals": dict(model="rock_crystals", size=90),
    "crystals_large": dict(model="rock_crystalsLargeA", size=130),
    "meteor": dict(model="meteor", size=90),
}
BIOMES = {
    "": {},  # Марс
    "ice": {
        "rock": (0.8, 0.88, 0.96), "rockDark": (0.58, 0.7, 0.84),
        "rockTrack": (0.9, 0.95, 1.0), "crystal": (0.3, 0.72, 1.0),
    },
    "toxic": {
        "rock": (0.46, 0.52, 0.38), "rockDark": (0.3, 0.35, 0.26),
        "rockTrack": (0.56, 0.62, 0.46), "crystal": (0.75, 1.0, 0.2),
    },
}
for biome, palette in BIOMES.items():
    prefix = f"decor_{biome}_" if biome else "decor_"
    for name, spec in DECOR.items():
        SPRITES[prefix + name] = dict(spec, recolor=palette)


def load_mtl(text):
    colors, name = {}, None
    for line in text.splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "newmtl":
            name = parts[1]
        elif parts[0] == "Kd" and name:
            colors[name] = np.array([float(x) for x in parts[1:4]])
    return colors


def load_obj(zf, name, recolor=None):
    """Возвращает (треугольники N×3×3, цвета N×3)."""
    colors = load_mtl(zf.read(f"{OBJ_DIR}{name}.mtl").decode())
    for material, rgb in (recolor or {}).items():
        colors[material] = np.array(rgb)
    verts, tris, tri_colors = [], [], []
    color = np.array([0.8, 0.8, 0.8])
    for line in zf.read(f"{OBJ_DIR}{name}.obj").decode().splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "v":
            verts.append([float(x) for x in parts[1:4]])
        elif parts[0] == "usemtl":
            color = colors.get(parts[1], color)
        elif parts[0] == "f":
            idx = [int(p.split("/")[0]) - 1 for p in parts[1:]]
            for i in range(1, len(idx) - 1):  # веер для многоугольников
                tris.append([verts[idx[0]], verts[idx[i]], verts[idx[i + 1]]])
                tri_colors.append(color)
    return np.array(tris), np.array(tri_colors)


def rotation_x(degrees):
    a = np.radians(degrees)
    c, s = np.cos(a), np.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rotation_y(degrees):
    a = np.radians(degrees)
    c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def render(tris, colors, size_px, screen_rotation, tilt, outline=False, axis=None):
    # Мир: Y — вверх. Смотрим сверху вниз: экран x = X, экран y = Z.
    # Поворот на экране = поворот модели вокруг вертикальной оси Y,
    # наклон камеры = поворот вокруг X (верх экрана уходит от зрителя).
    transform = rotation_x(-tilt) @ rotation_y(screen_rotation)
    tris = tris @ transform.T

    normals = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    lengths = np.linalg.norm(normals, axis=1, keepdims=True)
    normals = normals / np.where(lengths == 0, 1, lengths)
    # Смотрим вниз по -Y: видны грани с нормалью вверх (y > 0).
    light = LIGHT_DIR / np.linalg.norm(LIGHT_DIR)
    shade = AMBIENT + DIFFUSE * np.clip(normals @ light, 0, 1)
    half = light + np.array([0.0, 1.0, 0.0])
    half /= np.linalg.norm(half)
    highlight = SPECULAR * np.clip(normals @ half, 0, 1) ** SHININESS
    face_colors = np.clip(colors * shade[:, None] + highlight[:, None], 0, 1)

    xy = tris[:, :, [0, 2]]
    if axis:
        lo, hi = np.array([-axis, -axis]), np.array([axis, axis])
    else:
        lo, hi = xy.reshape(-1, 2).min(0), xy.reshape(-1, 2).max(0)
    span = (hi - lo).max()
    pad = 0.0 if axis else 0.04 * span
    scale = (size_px * SUPERSAMPLE) / (span + 2 * pad)
    w = int(np.ceil((hi[0] - lo[0] + 2 * pad) * scale))
    h = int(np.ceil((hi[1] - lo[1] + 2 * pad) * scale))

    px = (xy - lo + pad) * scale
    depth = tris[:, :, 1]
    zbuf = np.full((h, w), -np.inf)
    img = np.zeros((h, w, 4))

    for t in range(len(tris)):
        (x0, y0), (x1, y1), (x2, y2) = px[t]
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9:
            continue
        xmin, xmax = int(max(min(x0, x1, x2), 0)), int(min(max(x0, x1, x2) + 1, w))
        ymin, ymax = int(max(min(y0, y1, y2), 0)), int(min(max(y0, y1, y2) + 1, h))
        if xmin >= xmax or ymin >= ymax:
            continue
        gx, gy = np.meshgrid(np.arange(xmin, xmax) + 0.5, np.arange(ymin, ymax) + 0.5)
        w0 = ((x1 - gx) * (y2 - gy) - (x2 - gx) * (y1 - gy)) / area
        w1 = ((x2 - gx) * (y0 - gy) - (x0 - gx) * (y2 - gy)) / area
        w2 = 1 - w0 - w1
        inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
        z = w0 * depth[t, 0] + w1 * depth[t, 1] + w2 * depth[t, 2]
        region = zbuf[ymin:ymax, xmin:xmax]
        mask = inside & (z > region)
        region[mask] = z[mask]
        img[ymin:ymax, xmin:xmax][mask] = [*face_colors[t], 1.0]

    # Затемнение по высоте: чем ниже точка модели, тем темнее — даёт глубину.
    covered = np.isfinite(zbuf)
    if covered.any():
        zmin, zmax = zbuf[covered].min(), zbuf[covered].max()
        height = np.where(covered, (zbuf - zmin) / max(zmax - zmin, 1e-6), 1.0)
        img[..., :3] *= (1.0 - DEPTH_DARKEN * (1.0 - height))[..., None]
    gy, gx = np.mgrid[0:h, 0:w]
    diagonal = (gx / max(w - 1, 1) + gy / max(h - 1, 1)) / 2.0
    img[..., :3] *= (1.0 + LIGHT_GRADIENT * (0.5 - diagonal))[..., None]
    img[..., :3] = np.clip(img[..., :3], 0.0, 1.0)

    # Суперсэмплинг → сглаженные края (через premultiplied alpha).
    h2, w2 = h // SUPERSAMPLE * SUPERSAMPLE, w // SUPERSAMPLE * SUPERSAMPLE
    img = img[:h2, :w2]
    img[..., :3] *= img[..., 3:4]
    img = img.reshape(h2 // SUPERSAMPLE, SUPERSAMPLE, w2 // SUPERSAMPLE, SUPERSAMPLE, 4).mean((1, 3))
    alpha = img[..., 3:4]
    img[..., :3] /= np.where(alpha == 0, 1, alpha)
    image = Image.fromarray((img * 255).round().astype(np.uint8), "RGBA")
    return _add_outline(image) if outline else image


def _add_outline(image):
    """Тонкий тёмный контур: силуэт, расширенный на пиксель, под спрайтом."""
    padded = Image.new("RGBA", (image.width + 4, image.height + 4))
    padded.paste(image, (2, 2))
    ring = padded.getchannel("A").filter(ImageFilter.MaxFilter(3))
    base = Image.new("RGBA", padded.size, tuple(round(c * 255) for c in OUTLINE_COLOR) + (0,))
    base.putalpha(ring.point(lambda a: round(a * 0.85)))
    base.alpha_composite(padded)
    return base


def main(names):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ARCHIVE) as zf:
        for name in names or SPRITES:
            spec = SPRITES[name]
            tris, colors = load_obj(zf, spec["model"], spec.get("recolor"))
            if "part" in spec:
                # Часть модели по высоте: грани ниже / не ниже порога (по нижней точке).
                side, threshold = spec["part"]
                below = tris[:, :, 1].min(1) < threshold
                keep = below if side == "below" else ~below
                tris, colors = tris[keep], colors[keep]
            image = render(tris, colors, spec["size"], spec.get("rotation", 0), spec.get("tilt", 0), spec.get("outline", False), spec.get("axis"))
            image.save(OUT_DIR / f"{name}.png")
            print(f"{name}: {image.size[0]}x{image.size[1]}")


if __name__ == "__main__":
    main(sys.argv[1:])
