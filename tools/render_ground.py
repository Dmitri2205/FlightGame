#!/usr/bin/env python3
"""Текстура поверхности планеты (Blender, Cycles): грунт с рельефом.

Плоскость с процедурным материалом: крупные пятна грунта двух оттенков,
мелкая зернистость, трещины (Voronoi) и камешки — всё через рельеф (bump),
освещённый низким солнцем сверху-слева, поэтому земля выглядит объёмной,
а не залитой цветом.

Текстура бесшовная по вертикали (фон прокручивается вниз): рендерится
с запасом OVERLAP, и нижний запас плавно вливается в верх кадра.
Ширина — ровно экран (720), по горизонтали не повторяется.

    python tools/render_ground.py            # все биомы
    python tools/render_ground.py mars       # только указанные

Результат — art/ground/<биом>.jpg. Нужны bpy и Pillow.
"""
import math
import sys
import tempfile
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "art" / "ground"

WIDTH = 720
HEIGHT = 720
OVERLAP = 160
SAMPLES = 64
# Пикселей на единицу Blender.
PX = 100.0

# Биом → (основной цвет, тёмный, светлый) в sRGB. Основной — как ground_color главы.
BIOMES = {
    "mars": ((0.6, 0.35, 0.27), (0.4, 0.21, 0.15), (0.74, 0.5, 0.38)),
    "ice": ((0.56, 0.66, 0.76), (0.36, 0.46, 0.58), (0.86, 0.91, 0.97)),
    "toxic": ((0.28, 0.33, 0.22), (0.17, 0.21, 0.13), (0.42, 0.48, 0.3)),
}


def linear(rgb):
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb) + (1.0,)


def build_scene(palette, seed):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"

    world = bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.58, 0.65, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = 3.0
    sun_data.angle = math.radians(3)
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    # Низкое солнце сверху-слева — рельеф отбрасывает тени.
    sun.rotation_euler = Vector((0.7, -0.5, -0.55)).to_track_quat("-Z", "Y").to_euler()

    w, h = WIDTH / PX, (HEIGHT + OVERLAP) / PX
    bpy.ops.mesh.primitive_plane_add(size=1)
    plane = bpy.context.active_object
    plane.scale = (w, h, 1)

    mat = bpy.data.materials.new("Ground")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.95
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 13.7, seed * 7.3, 0)
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    vec = mapping.outputs["Vector"]

    def noise(scale, detail, roughness=0.55):
        node = nodes.new("ShaderNodeTexNoise")
        node.inputs["Scale"].default_value = scale
        node.inputs["Detail"].default_value = detail
        node.inputs["Roughness"].default_value = roughness
        links.new(vec, node.inputs["Vector"])
        return node

    base, dark, light = (linear(c) for c in palette)
    # Крупные пятна: тёмный ↔ основной ↔ светлый.
    big = noise(1.2, 8)
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = dark
    ramp.color_ramp.elements[1].position = 0.68
    ramp.color_ramp.elements[1].color = light
    mid = ramp.color_ramp.elements.new(0.5)
    mid.color = base
    links.new(big.outputs["Fac"], ramp.inputs["Fac"])

    # Зерно.
    grain = noise(40.0, 10, 0.7)
    grain_mix = nodes.new("ShaderNodeMix")
    grain_mix.data_type = "RGBA"
    grain_mix.blend_type = "OVERLAY"
    grain_mix.inputs["Factor"].default_value = 0.35
    links.new(ramp.outputs["Color"], grain_mix.inputs["A"])
    links.new(grain.outputs["Color"], grain_mix.inputs["B"])

    # Трещины: Voronoi «расстояние до края» по искажённым координатам —
    # неровные тонкие линии, и только местами (маска из шума).
    warp = noise(1.5, 4)
    warped = nodes.new("ShaderNodeVectorMath")
    warped.operation = "MULTIPLY_ADD"
    links.new(warp.outputs["Color"], warped.inputs[0])
    warped.inputs[1].default_value = (0.35, 0.35, 0.35)
    links.new(vec, warped.inputs[2])
    cracks = nodes.new("ShaderNodeTexVoronoi")
    cracks.feature = "DISTANCE_TO_EDGE"
    cracks.inputs["Scale"].default_value = 3.5
    links.new(warped.outputs["Vector"], cracks.inputs["Vector"])
    crack_ramp = nodes.new("ShaderNodeMapRange")
    crack_ramp.inputs["From Min"].default_value = 0.0
    crack_ramp.inputs["From Max"].default_value = 0.018
    links.new(cracks.outputs["Distance"], crack_ramp.inputs["Value"])
    invert = nodes.new("ShaderNodeMath")
    invert.operation = "SUBTRACT"
    invert.inputs[0].default_value = 1.0
    links.new(crack_ramp.outputs["Result"], invert.inputs[1])
    mask = noise(0.7, 2)
    mask_ramp = nodes.new("ShaderNodeMapRange")
    mask_ramp.inputs["From Min"].default_value = 0.48
    mask_ramp.inputs["From Max"].default_value = 0.6
    links.new(mask.outputs["Fac"], mask_ramp.inputs["Value"])
    crack_amount = nodes.new("ShaderNodeMath")
    crack_amount.operation = "MULTIPLY"
    links.new(invert.outputs["Value"], crack_amount.inputs[0])
    links.new(mask_ramp.outputs["Result"], crack_amount.inputs[1])
    crack_mix = nodes.new("ShaderNodeMix")
    crack_mix.data_type = "RGBA"
    crack_mix.blend_type = "MULTIPLY"
    links.new(grain_mix.outputs["Result"], crack_mix.inputs["A"])
    crack_mix.inputs["B"].default_value = (0.6, 0.6, 0.6, 1)
    links.new(crack_amount.outputs["Value"], crack_mix.inputs["Factor"])

    # Камешки: мелкие светлые и тёмные пятнышки.
    stones = nodes.new("ShaderNodeTexVoronoi")
    stones.inputs["Scale"].default_value = 26.0
    stones.inputs["Randomness"].default_value = 1.0
    links.new(vec, stones.inputs["Vector"])
    stone_size = nodes.new("ShaderNodeMapRange")
    stone_size.inputs["From Min"].default_value = 0.12
    stone_size.inputs["From Max"].default_value = 0.2
    stone_size.inputs["To Min"].default_value = 1.0
    stone_size.inputs["To Max"].default_value = 0.0
    links.new(stones.outputs["Distance"], stone_size.inputs["Value"])
    stone_pick = nodes.new("ShaderNodeSeparateColor")
    links.new(stones.outputs["Color"], stone_pick.inputs["Color"])
    stone_keep = nodes.new("ShaderNodeMath")
    stone_keep.operation = "GREATER_THAN"
    stone_keep.inputs[1].default_value = 0.6
    links.new(stone_pick.outputs["Red"], stone_keep.inputs[0])
    stone_amount = nodes.new("ShaderNodeMath")
    stone_amount.operation = "MULTIPLY"
    links.new(stone_size.outputs["Result"], stone_amount.inputs[0])
    links.new(stone_keep.outputs["Value"], stone_amount.inputs[1])
    stone_mix = nodes.new("ShaderNodeMix")
    stone_mix.data_type = "RGBA"
    stone_mix.blend_type = "MIX"
    links.new(crack_mix.outputs["Result"], stone_mix.inputs["A"])
    stone_mix.inputs["B"].default_value = light
    links.new(stone_amount.outputs["Value"], stone_mix.inputs["Factor"])
    links.new(stone_mix.outputs["Result"], bsdf.inputs["Base Color"])

    # Рельеф: холмики + зерно + бугорки + камешки − трещины.
    pebbles = nodes.new("ShaderNodeTexVoronoi")
    pebbles.inputs["Scale"].default_value = 9.0
    links.new(vec, pebbles.inputs["Vector"])
    peb = nodes.new("ShaderNodeMapRange")
    peb.inputs["From Min"].default_value = 0.0
    peb.inputs["From Max"].default_value = 0.35
    peb.inputs["To Min"].default_value = 1.0
    peb.inputs["To Max"].default_value = 0.0
    links.new(pebbles.outputs["Distance"], peb.inputs["Value"])
    height = nodes.new("ShaderNodeMath")
    height.operation = "MULTIPLY_ADD"
    links.new(big.outputs["Fac"], height.inputs[0])
    height.inputs[1].default_value = 3.0
    links.new(peb.outputs["Result"], height.inputs[2])
    height2 = nodes.new("ShaderNodeMath")
    height2.operation = "ADD"
    links.new(height.outputs["Value"], height2.inputs[0])
    links.new(grain.outputs["Fac"], height2.inputs[1])
    height3 = nodes.new("ShaderNodeMath")
    height3.operation = "SUBTRACT"
    links.new(height2.outputs["Value"], height3.inputs[0])
    links.new(crack_amount.outputs["Value"], height3.inputs[1])
    height4 = nodes.new("ShaderNodeMath")
    height4.operation = "MULTIPLY_ADD"
    links.new(stone_amount.outputs["Value"], height4.inputs[0])
    height4.inputs[1].default_value = 1.5
    links.new(height3.outputs["Value"], height4.inputs[2])
    height3 = height4
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.9
    bump.inputs["Distance"].default_value = 0.03
    links.new(height3.outputs["Value"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    plane.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(w, h)
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, 0, 10)
    scene.camera = cam
    scene.render.resolution_x = WIDTH
    scene.render.resolution_y = HEIGHT + OVERLAP
    scene.render.resolution_percentage = 100


def render_biome(name):
    build_scene(BIOMES[name], seed=list(BIOMES).index(name) + 1)
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "ground.png"
        bpy.context.scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        raw = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    # Бесшовность по вертикали: низ запаса (строки HEIGHT…) плавно переходит
    # в верх кадра, так что последняя строка стыкуется с первой.
    tile = raw[:HEIGHT].copy()
    t = np.linspace(0.0, 1.0, OVERLAP)[:, None, None]
    tile[:OVERLAP] = raw[HEIGHT:HEIGHT + OVERLAP] * (1.0 - t) + raw[:OVERLAP] * t
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray(tile.clip(0, 255).astype(np.uint8)).save(OUT_DIR / f"{name}.jpg", quality=88)
    print(f"{name}: {WIDTH}x{HEIGHT}", flush=True)


def main(names):
    for name in names or BIOMES:
        render_biome(name)


if __name__ == "__main__":
    main(sys.argv[1:])
