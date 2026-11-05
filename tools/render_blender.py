#!/usr/bin/env python3
"""Рендер спрайтов «вид сверху» в Blender (Cycles) — объёмный, «под металл».

Тот же список спрайтов и те же параметры, что у tools/render_topdown.py
(SPRITES: модель, размер, поворот, наклон, перекраска, части), но вместо
самописного плоского растеризатора — настоящий рендер с трассировкой лучей:

- мягкое освещение от неба + солнце сверху-слева → тени в углублениях (AO);
- металл отражает небо, у краёв скруглённые блики (Bevel-шейдер — фаска
  на гранях low-poly моделей без изменения геометрии);
- шум в шероховатости и лёгкий рельеф — потёртости, «не пластик»;
- скалы и кратеры — матовые, с крупным рельефом.

Нужен Blender как Python-модуль (pip install bpy) и Pillow:

    python tools/render_blender.py                 # все спрайты
    python tools/render_blender.py ship_falcon     # только указанные

Результат — art/sprites/<имя>.png (прозрачный фон), как у render_topdown.py.
"""
import math
import sys
import tempfile
import zipfile
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_topdown as base  # noqa: E402  (SPRITES, палитры, контур)

# Рендер в несколько раз крупнее нужного и уменьшение — чёткие мелкие детали.
OVERSAMPLE = 3
SAMPLES = 96
# Солнце: сверху-слева-спереди (как в render_topdown), мягкие тени.
SUN_DIRECTION = (0.75, -0.55, -0.75)   # куда светит (Blender: Z вверх, -Z вниз)
SUN_STRENGTH = 4.0
SUN_ANGLE = math.radians(8)
SKY_STRENGTH = 0.6

# Материалы пака → свойства поверхности.
# panels — швы обшивки (тёмные линии + рельеф), как у настоящей техники.
METAL = {"metallic": 0.45, "roughness": 0.3, "bump": 0.08, "wear": 0.25, "panels": True}
PAINT = {"metallic": 0.25, "roughness": 0.35, "bump": 0.06, "wear": 0.2, "panels": True}
DARK = {"metallic": 0.2, "roughness": 0.55, "bump": 0.05, "wear": 0.15}
ROCK = {"metallic": 0.0, "roughness": 0.92, "bump": 0.5, "wear": 0.4}
GLOW = {"metallic": 0.0, "roughness": 0.2, "bump": 0.0, "wear": 0.0, "emission": 1.5}
# Затемнение по высоте: самые низкие места модели темнее на столько
# (дно кратера, низ корпуса) — глубина читается и при виде строго сверху.
DEPTH_DARKEN = {"rock": 0.5, "default": 0.3}

# Сколько панелей обшивки укладывается по длине модели (у любой модели одинаково).
PANELS_PER_MODEL = 4.0
SURFACE = {
    "metal": METAL, "metalDark": METAL, "metalRed": PAINT, "dark": DARK,
    "rock": ROCK, "rockDark": ROCK, "rockTrack": ROCK, "crystal": GLOW,
}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # Standard, а не AgX/Filmic: цвета остаются как в палитре пака.
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    world = bpy.data.worlds.new("Sky")
    scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    nodes.clear()
    # Небо-градиент: светлый зенит, тёмный горизонт — металлу есть что отражать.
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[0].color = (0.12, 0.11, 0.13, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.85, 0.88, 0.95, 1)
    bg = nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = SKY_STRENGTH
    out = nodes.new("ShaderNodeOutputWorld")
    links = world.node_tree.links
    links.new(coord.outputs["Generated"], sep.inputs[0])
    links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bg.inputs["Color"])
    links.new(bg.outputs["Background"], out.inputs["Surface"])

    sun_data = bpy.data.lights.new("Sun", "SUN")
    sun_data.energy = SUN_STRENGTH
    sun_data.angle = SUN_ANGLE
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = Vector(SUN_DIRECTION).to_track_quat("-Z", "Y").to_euler()


def srgb_to_linear(rgb):
    """Цвета пака заданы в sRGB, а шейдеры Blender ждут линейные."""
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb)


def make_material(name, rgb, model_size=1.0):
    props = SURFACE.get(name, METAL)
    rgb = srgb_to_linear(rgb)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = props["metallic"]

    coord = nodes.new("ShaderNodeTexCoord")
    # Потёртости: шум в шероховатости и чуть темнее/светлее основной цвет.
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 18.0
    noise.inputs["Detail"].default_value = 8.0
    links.new(coord.outputs["Object"], noise.inputs["Vector"])
    rough = nodes.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = props["roughness"] - props["wear"] * 0.3
    rough.inputs["To Max"].default_value = props["roughness"] + props["wear"] * 0.5
    links.new(noise.outputs["Fac"], rough.inputs["Value"])
    links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])

    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = props["wear"] * 0.6
    tint.inputs["A"].default_value = (*rgb, 1)
    links.new(noise.outputs["Color"], tint.inputs["B"])
    color_out = tint.outputs["Result"]

    panels = None
    if props.get("panels"):
        # Швы обшивки: «кирпичная» текстура — тонкие тёмные линии между панелями.
        panels = nodes.new("ShaderNodeTexBrick")
        panels.inputs["Scale"].default_value = PANELS_PER_MODEL / model_size
        panels.inputs["Mortar Size"].default_value = 0.012
        panels.inputs["Brick Width"].default_value = 1.0
        panels.inputs["Row Height"].default_value = 0.6
        panels.offset = 0.3
        panels.inputs["Mortar Smooth"].default_value = 0.3
        panels.inputs["Color1"].default_value = (1, 1, 1, 1)
        panels.inputs["Color2"].default_value = (0.93, 0.93, 0.93, 1)
        panels.inputs["Mortar"].default_value = (0.35, 0.35, 0.35, 1)
        links.new(coord.outputs["Object"], panels.inputs["Vector"])
        seams = nodes.new("ShaderNodeMix")
        seams.data_type = "RGBA"
        seams.blend_type = "MULTIPLY"
        seams.inputs["Factor"].default_value = 1.0
        links.new(color_out, seams.inputs["A"])
        links.new(panels.outputs["Color"], seams.inputs["B"])
        color_out = seams.outputs["Result"]
    # Глубина: Generated Z — 0 у низа модели, 1 у верха.
    depth = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Generated"], depth.inputs[0])
    shade = nodes.new("ShaderNodeMapRange")
    shade.inputs["To Min"].default_value = 1.0 - DEPTH_DARKEN["rock" if props is ROCK else "default"]
    shade.inputs["To Max"].default_value = 1.0
    links.new(depth.outputs["Z"], shade.inputs["Value"])
    deepen = nodes.new("ShaderNodeMix")
    deepen.data_type = "RGBA"
    deepen.blend_type = "MULTIPLY"
    deepen.inputs["Factor"].default_value = 1.0
    links.new(color_out, deepen.inputs["A"])
    gray = nodes.new("ShaderNodeCombineXYZ")
    for axis in ("X", "Y", "Z"):
        links.new(shade.outputs["Result"], gray.inputs[axis])
    links.new(gray.outputs["Vector"], deepen.inputs["B"])
    color_out = deepen.outputs["Result"]
    links.new(color_out, bsdf.inputs["Base Color"])

    # Фаска на рёбрах (только в шейдере) + мелкий рельеф.
    bevel = nodes.new("ShaderNodeBevel")
    bevel.samples = 8
    bevel.inputs["Radius"].default_value = 0.012
    bump_noise = nodes.new("ShaderNodeTexNoise")
    bump_noise.inputs["Scale"].default_value = 60.0 if props["bump"] < 0.3 else 9.0
    bump_noise.inputs["Detail"].default_value = 10.0
    links.new(coord.outputs["Object"], bump_noise.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = props["bump"]
    bump.inputs["Distance"].default_value = 0.02
    links.new(bump_noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bevel.outputs["Normal"], bump.inputs["Normal"])
    normal_out = bump.outputs["Normal"]
    if panels:
        # Швы чуть утоплены.
        seam_bump = nodes.new("ShaderNodeBump")
        seam_bump.inputs["Strength"].default_value = 0.35
        seam_bump.inputs["Distance"].default_value = 0.01
        links.new(panels.outputs["Fac"], seam_bump.inputs["Height"])
        links.new(normal_out, seam_bump.inputs["Normal"])
        normal_out = seam_bump.outputs["Normal"]
    links.new(normal_out, bsdf.inputs["Normal"])

    if props.get("emission"):
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = props["emission"]
    return mat


def import_model(zf, model, recolor, part):
    """Импорт OBJ из архива; материалы → объёмные; part — оставить часть по высоте."""
    colors = base.load_mtl(zf.read(f"{base.OBJ_DIR}{model}.mtl").decode())
    for material, rgb in (recolor or {}).items():
        colors[material] = tuple(rgb)
    with tempfile.TemporaryDirectory() as tmp:
        for ext in ("obj", "mtl"):
            (Path(tmp) / f"{model}.{ext}").write_bytes(zf.read(f"{base.OBJ_DIR}{model}.{ext}"))
        bpy.ops.wm.obj_import(filepath=str(Path(tmp) / f"{model}.obj"))
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = objects[0]
    for o in objects:
        o.select_set(True)
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # Импортёр переводит Y-вверх (OBJ) в Z-вверх (Blender) поворотом объекта —
    # «впекаем» его в геометрию, чтобы дальше крутить объект с нуля.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    # Заменяем материалы из .mtl на свои (имя материала = имя в паке).
    model_size = max(obj.dimensions)
    for slot in obj.material_slots:
        name = slot.material.name.split(".")[0] if slot.material else "metal"
        rgb = tuple(colors.get(name, (0.8, 0.8, 0.8)))
        slot.material = make_material(name, rgb, model_size)

    if part:
        side, threshold = part
        # OBJ Y (высота) → Blender Z.
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        doomed = []
        for face in mesh.faces:
            low = min((obj.matrix_world @ v.co).z for v in face.verts)
            below = low < threshold
            if (side == "below") != below:
                doomed.append(face)
        bmesh.ops.delete(mesh, geom=doomed, context="FACES")
        mesh.to_mesh(obj.data)
        mesh.free()
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def render_sprite(name, spec, zf, out_dir):
    reset_scene()
    obj = import_model(zf, spec["model"], spec.get("recolor"), spec.get("part"))
    # Поворот на экране — вокруг вертикали; наклон — вокруг X (верх экрана уходит от зрителя).
    obj.rotation_euler = (math.radians(-spec.get("tilt", 0)), 0, math.radians(spec.get("rotation", 0)))
    bpy.context.view_layer.update()

    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    if spec.get("axis"):
        r = spec["axis"]
        lo, hi = Vector((-r, -r)), Vector((r, r))
    else:
        verts = [obj.matrix_world @ v.co for v in obj.data.vertices]
        lo = Vector((min(v.x for v in verts), min(v.y for v in verts)))
        hi = Vector((max(v.x for v in verts), max(v.y for v in verts)))
        pad = 0.04 * max(hi - lo)
        lo -= Vector((pad, pad))
        hi += Vector((pad, pad))
    span = hi - lo
    top = max(c.z for c in corners) + 5.0

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(span.x, span.y)
    cam = bpy.data.objects.new("Camera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, top)
    cam.rotation_euler = (0, 0, 0)  # смотрит вниз, верх кадра = +Y
    bpy.context.scene.camera = cam

    size = spec["size"]
    scale = size / max(span.x, span.y)
    w, h = max(1, round(span.x * scale)), max(1, round(span.y * scale))
    render = bpy.context.scene.render
    render.resolution_x, render.resolution_y = w * OVERSAMPLE, h * OVERSAMPLE
    render.resolution_percentage = 100
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "out.png"
        render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        image = Image.open(path).convert("RGBA")
        image.load()
    image = image.resize((w, h), Image.LANCZOS)
    if spec.get("outline"):
        image = base._add_outline(image)
    image.save(out_dir / f"{name}.png")
    print(f"{name}: {image.size[0]}x{image.size[1]}", flush=True)


def main(names):
    base.OUT_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(base.ARCHIVE) as zf:
        for name in names or base.SPRITES:
            render_sprite(name, base.SPRITES[name], zf, base.OUT_DIR)


if __name__ == "__main__":
    main(sys.argv[1:])
