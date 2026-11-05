class_name View3D
extends Node3D
## Прототип 2.5D-вида: та же игра (логика, коллизии, траектории — на плоскости,
## в 2D-узлах уровня), а картинка — 3D-сцена с камерой сзади-сверху.
##
## Каждому игровому объекту (игрок, враги, наземные, постройки) создаётся
## 3D-«двойник» из модели пака (models/*.glb), который каждый кадр повторяет
## положение, поворот и крен 2D-объекта. Пули и звёзды — MultiMesh (дёшево).
## Взрывы — по сигналу FX.spawned. 2D-картинка уровня при этом спрятана.
##
## Плоскость 2D → 3D: x → X, y → Z (вниз по экрану = к камере), 1 px = S ед.
## Фон — космос: звёзды, газовый гигант, планета, два солнца.

const S := 0.01
## Камера: выше и круче, чем раньше (траектории видны сверху), уже угол —
## модели крупнее. По горизонтали едет за игроком, на виражах чуть кренится.
const CAMERA_OFFSET := Vector3(0.0, 9.0, 10.5)
const CAMERA_LOOK := Vector3(0.0, -9.0, -10.0)
const CAMERA_FOV := 46.0
const CAMERA_FOLLOW := 3.5
## Доля сдвига игрока, на которую сдвигается камера (остальное — запас по краям).
const CAMERA_FOLLOW_SHARE := 0.75
## Высота полёта самолётов над землёй.
const AIR_HEIGHT := 1.1

## Палитры перекраски материалов пака (по имени материала).
const ENEMY := {"metalRed": Color(0.75, 0.25, 0.65), "metal": Color(0.6, 0.58, 0.66)}
const BOSS := {"metalRed": Color(0.85, 0.2, 0.3), "metal": Color(0.5, 0.48, 0.55), "metalDark": Color(0.38, 0.36, 0.44)}

## Сцена 2D-объекта → модель, размер (px, как у спрайта), высота, палитра.
const TYPES := {
	"res://scenes/game/enemy_fighter.tscn": {"model": "craft_speederB", "size": 64.0, "air": true, "palette": "enemy"},
	"res://scenes/game/enemy_gunship.tscn": {"model": "craft_miner", "size": 88.0, "air": true, "palette": "enemy"},
	"res://scenes/game/miniboss.tscn": {"model": "craft_miner", "size": 150.0, "air": true, "palette": "boss"},
	"res://scenes/game/boss.tscn": {"model": "boss", "size": 210.0, "air": true, "palette": "boss"},
	"res://scenes/game/ground_tank.tscn": {"model": "rover", "size": 50.0, "air": false, "palette": "enemy"},
	"res://scenes/game/ground_turret.tscn": {"model": "turret_double", "size": 84.0, "air": false, "palette": "enemy", "turret": true},
}
const SHIP_MODELS := {"falcon": "craft_speederA", "swift": "craft_racer", "bastion": "craft_cargoB"}
## Босс — та же композиция, что у спрайта (координаты Blender: x, к хвосту, вверх).
const BOSS_PARTS := [
	["craft_speederC", Vector3(0.0, 1.05, -0.05), 1.35],
	["craft_cargoA", Vector3(0.0, 0.0, 0.0), 1.2],
	["craft_miner", Vector3(-1.55, 0.1, 0.0), 0.6],
	["craft_miner", Vector3(1.55, 0.1, 0.0), 0.6],
	["turret_double", Vector3(-0.45, -0.55, 0.9), 0.9],
	["turret_double", Vector3(0.45, -0.55, 0.9), 0.9],
]

## Уровень (level.gd): берём у него контейнеры пуль и подбираемого.
var level

var _camera: Camera3D
var _ground_material: StandardMaterial3D
var _scroll := 0.0
var _scroll_speed := 120.0
## id 2D-узла → {"node": 2D, "proxy": Node3D}
var _proxies := {}
var _model_cache := {}
var _player_bullets: MultiMeshInstance3D
var _enemy_bullets: MultiMeshInstance3D
var _pickups: MultiMeshInstance3D
## Полосы скорости: тонкие светлые штрихи пролетают мимо камеры — ощущение полёта.
var _streaks: MultiMeshInstance3D
var _streak_positions: Array[Vector3] = []
var _camera_roll := 0.0
## Декор земли (скалы, кратеры): едет вместе с землёй и возвращается вперёд.
var _decor: Array[Node3D] = []
const DECOR_MODELS := ["rock_largeA", "rock_largeB", "rocks_smallA", "crater", "craterLarge", "meteor"]
const DECOR_COUNT := 36
const DECOR_NEAR := 16.0
const DECOR_FAR := -50.0


## Без экрана (CI) рендер-заглушка не создаёт примитивные меши и ругается на
## каждый — там строим только двойники из моделей (проверка логики).
var _headless := false


func setup(p_level) -> void:
	level = p_level
	_headless = DisplayServer.get_name() == "headless"
	_build_camera()
	if not _headless:
		_build_environment()
		_build_ground()
		_build_decor()
		_build_streaks()
		_build_space()
		_player_bullets = _make_multimesh(_glow_sphere(0.05, Color(1.0, 0.75, 0.3)))
		_enemy_bullets = _make_multimesh(_glow_sphere(0.08, Color(1.0, 0.35, 0.85)))
		_pickups = _make_multimesh(_glow_sphere(0.07, Color(1.0, 0.85, 0.2)))
		FX.spawned.connect(_on_fx)
	var background := get_tree().get_first_node_in_group("background")
	if background and "scroll_speed" in background:
		_scroll_speed = background.scroll_speed


func _exit_tree() -> void:
	Arena.drag_scale_override = 0.0
	if FX.spawned.is_connected(_on_fx):
		FX.spawned.disconnect(_on_fx)


## Точка 2D-мира → 3D (на земле, y = 0).
func to_3d(p: Vector2) -> Vector3:
	var size := Arena.rect().size
	return Vector3((p.x - size.x / 2.0) * S, 0.0, (p.y - size.y / 2.0) * S)


func _process(delta: float) -> void:
	_scroll += _scroll_speed * delta
	_sync_proxies()
	_update_camera(delta)
	_update_drag_scale()
	if _headless:
		return
	_ground_material.uv1_offset = Vector3(0.0, -_scroll * S / 9.0, 0.0)
	_move_decor(_scroll_speed * delta * S)
	_move_streaks(delta)
	_sync_multimeshes()


# --- Сцена -------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://scenes/game/view3d/space_sky.gdshader")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.42, 0.55)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.1, 0.22)
	# Дымка гуще: дальние волны проступают из неё, а не видны с горизонта.
	env.fog_density = 0.05
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	# Главное солнце: тёплый свет сбоку-спереди, длинные тени.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-35.0, -40.0, 0.0)
	add_child(sun)
	# Второе солнце: холодная подсветка с другой стороны, без теней.
	var sun2 := DirectionalLight3D.new()
	sun2.light_color = Color(0.55, 0.7, 1.0)
	sun2.light_energy = 0.4
	sun2.rotation_degrees = Vector3(-25.0, 130.0, 0.0)
	add_child(sun2)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = CAMERA_FOV
	_camera.far = 600.0
	_camera.position = CAMERA_OFFSET
	add_child(_camera)
	_camera.look_at(CAMERA_OFFSET + CAMERA_LOOK)
	_camera.current = true


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 80.0)
	_ground_material = StandardMaterial3D.new()
	var chapter := GameState.current_chapter_data()
	if chapter.ground_texture:
		_ground_material.albedo_texture = chapter.ground_texture
	else:
		_ground_material.albedo_color = chapter.ground_color
	_ground_material.roughness = 1.0
	# Одна плитка текстуры = ширина игрового поля (9 ед.).
	_ground_material.uv1_scale = Vector3(60.0 / 9.0, 80.0 / 9.0, 1.0)
	plane.material = _ground_material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position = Vector3(0.0, 0.0, -20.0)
	add_child(ground)


func _build_decor() -> void:
	var tint := GameState.current_chapter_data().ground_color
	for i in DECOR_COUNT:
		var model := _instance_model(DECOR_MODELS.pick_random())
		if model == null:
			continue
		_tint(model, {"rock": tint.lightened(0.15), "rockDark": tint.darkened(0.25), "rockTrack": tint})
		model.scale = Vector3.ONE * randf_range(0.5, 1.6)
		model.rotation.y = randf() * TAU
		_place_decor(model, randf_range(DECOR_FAR, DECOR_NEAR))
		add_child(model)
		_decor.append(model)


func _place_decor(model: Node3D, z: float) -> void:
	# Реже — на самой полосе боя, чаще — по краям.
	var side := 1.0 if randf() < 0.5 else -1.0
	var x := randf_range(-4.0, 4.0) if randf() < 0.3 else side * randf_range(4.5, 18.0)
	model.position = Vector3(x, 0.0, z)


func _move_decor(distance: float) -> void:
	for model in _decor:
		model.position.z += distance
		if model.position.z > DECOR_NEAR:
			_place_decor(model, DECOR_FAR)


func _build_space() -> void:
	# Газовый гигант над горизонтом.
	var giant := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 38.0
	sphere.height = 76.0
	var giant_material := ShaderMaterial.new()
	giant_material.shader = preload("res://scenes/game/view3d/gas_giant.gdshader")
	sphere.material = giant_material
	giant.mesh = sphere
	giant.position = Vector3(-55.0, 30.0, -230.0)
	giant.rotation_degrees = Vector3(0.0, 0.0, 18.0)
	add_child(giant)
	# Маленькая ледяная планета.
	add_child(_planet(9.0, Color(0.45, 0.65, 0.85), Vector3(60.0, 26.0, -170.0)))
	# Два солнца — яркие диски с ореолом.
	add_child(_star_disc(10.0, Color(1.0, 0.75, 0.4), Vector3(95.0, 55.0, -300.0)))
	add_child(_star_disc(6.0, Color(0.7, 0.85, 1.0), Vector3(-110.0, 70.0, -320.0)))


func _planet(radius: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	return node


func _star_disc(radius: float, color: Color, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var core := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color.lightened(0.4)
	material.disable_fog = true
	mesh.material = material
	core.mesh = mesh
	root.add_child(core)
	# Ореол — плоский квадрат с мягким пятном, всегда лицом к камере.
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 7.0
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.albedo_texture = preload("res://fx/soft_glow.tres")
	halo_material.albedo_color = Color(color, 0.8)
	halo_material.disable_fog = true
	quad.material = halo_material
	halo.mesh = quad
	root.add_child(halo)
	return root


# --- Двойники объектов -------------------------------------------------------

func _sync_proxies() -> void:
	var alive := {}
	var nodes: Array = []
	nodes.append_array(get_tree().get_nodes_in_group("player"))
	nodes.append_array(get_tree().get_nodes_in_group("enemies"))
	nodes.append_array(get_tree().get_nodes_in_group("destructibles"))
	for node in nodes:
		if not is_instance_valid(node) or not node is Node2D:
			continue
		var id: int = node.get_instance_id()
		alive[id] = true
		if not _proxies.has(id):
			var proxy := _make_proxy(node)
			if proxy == null:
				continue
			add_child(proxy)
			_proxies[id] = {"node": node, "proxy": proxy}
		_update_proxy(node, _proxies[id].proxy)
	for id in _proxies.keys():
		if not alive.has(id):
			var entry: Dictionary = _proxies[id]
			if is_instance_valid(entry.proxy):
				entry.proxy.queue_free()
			_proxies.erase(id)


func _make_proxy(node) -> Node3D:
	var info := {}
	if node.is_in_group("player"):
		var ship := GameState.get_selected_ship()
		info = {"model": SHIP_MODELS.get(ship.id, "craft_speederA"), "size": 84.0 * ship.visual_scale, "air": true,
			"palette": "player", "color": ship.color, "player": true}
	elif node.is_in_group("destructibles"):
		info = {"model": node.model_name, "size": node.sprite_size, "air": false, "palette": "enemy"}
	else:
		info = TYPES.get(node.scene_file_path, {})
	if info.is_empty() or str(info.model) == "":
		return null
	var holder := Node3D.new()
	var model := _build_boss() if info.model == "boss" else _instance_model(info.model)
	if model == null:
		return null
	# Масштаб под размер спрайта: большая сторона модели = size px.
	var aabb := _model_aabb(model)
	var longest := maxf(aabb.size.x, aabb.size.z)
	var factor := float(info.size) * S / longest if longest > 0.0 else 1.0
	model.scale = Vector3.ONE * factor
	# У моделей пака начало координат на днище, а не в центре — сдвигаем
	# модель так, чтобы центр габаритов совпал с точкой 2D-объекта (и крен
	# вращал корабль вокруг его середины, а не вокруг края).
	model.position = -aabb.get_center() * factor
	match str(info.get("palette", "")):
		"enemy":
			_tint(model, ENEMY)
		"boss":
			_tint(model, BOSS)
		"player":
			_tint(model, {"metalRed": info.color})
	# Крен и повороты — у промежуточного узла в центре модели.
	var pivot := Node3D.new()
	pivot.name = "Model"
	pivot.add_child(model)
	holder.add_child(pivot)
	holder.set_meta("info", info)
	return holder


func _update_proxy(node, proxy: Node3D) -> void:
	var info: Dictionary = proxy.get_meta("info")
	var pos := to_3d(node.global_position)
	pos.y = AIR_HEIGHT if info.air else 0.0
	proxy.position = pos
	var model: Node3D = proxy.get_node("Model")
	if info.get("player", false):
		# Игрок нарисован носом вверх (к горизонту), крен — вращение модели.
		# Мигание при уроне — как у 2D-узла.
		proxy.visible = node.visible
		proxy.rotation = Vector3(0.0, PI, 0.0)
		model.rotation = Vector3(0.0, 0.0, -float(node.visual_bank) * 0.7)
		return
	if info.get("turret", false):
		var head := node.get_node_or_null("Head") as Node2D
		proxy.rotation = Vector3(0.0, -(head.global_rotation if head else node.global_rotation), 0.0)
	else:
		proxy.rotation = Vector3(0.0, -node.global_rotation, 0.0)
	# Крен врага на вираже (PatternMotion.bank).
	var motion = node.get("_motion")
	if motion:
		model.rotation = Vector3(0.0, 0.0, float(motion.bank) * 0.7)
	if node.has_method("is_destroyed"):
		proxy.visible = not node.is_destroyed()


func _instance_model(model_name: String) -> Node3D:
	if not _model_cache.has(model_name):
		_model_cache[model_name] = load("res://models/%s.glb" % model_name)
	var scene: PackedScene = _model_cache[model_name]
	return scene.instantiate() if scene else null


func _build_boss() -> Node3D:
	var root := Node3D.new()
	for part in BOSS_PARTS:
		var piece := _instance_model(part[0])
		if piece == null:
			continue
		var b: Vector3 = part[1]
		# Blender (x, к хвосту, вверх) → Godot (x, вверх, к носу = +Z).
		piece.position = Vector3(b.x, b.z, -b.y)
		piece.scale = Vector3.ONE * float(part[2])
		root.add_child(piece)
	return root


## Габариты модели в её собственных координатах (модель ещё не в дереве).
func _model_aabb(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		var box := _relative_transform(model, mi) * mi.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current and current != root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


## Перекрасить материалы модели по имени (metalRed, metal…).
func _tint(model: Node3D, palette: Dictionary) -> void:
	for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if material and palette.has(material.resource_name):
				var copy := material.duplicate() as StandardMaterial3D
				copy.albedo_color = palette[material.resource_name]
				mi.set_surface_override_material(i, copy)


# --- Пули, звёзды, взрывы ------------------------------------------------------

func _glow_sphere(radius: float, color: Color) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.disable_fog = true
	mesh.material = material
	return mesh


func _make_multimesh(mesh: Mesh) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = 600
	multimesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _sync_multimeshes() -> void:
	var player_count := 0
	var enemy_count := 0
	var player_mm := _player_bullets.multimesh
	var enemy_mm := _enemy_bullets.multimesh
	for bullet in level.projectiles.get_children():
		var b := bullet as CollisionObject2D
		if b == null:
			continue
		var pos := to_3d(b.global_position)
		pos.y = AIR_HEIGHT
		if b.collision_layer == 8:
			if enemy_count < enemy_mm.instance_count:
				enemy_mm.set_instance_transform(enemy_count, Transform3D(Basis(), pos))
				enemy_count += 1
		elif player_count < player_mm.instance_count:
			player_mm.set_instance_transform(player_count, Transform3D(Basis(), pos))
			player_count += 1
	player_mm.visible_instance_count = player_count
	enemy_mm.visible_instance_count = enemy_count

	var pickup_count := 0
	var pickup_mm := _pickups.multimesh
	for pickup in level.pickups.get_children():
		var p := pickup as Node2D
		if p == null or pickup_count >= pickup_mm.instance_count:
			continue
		var pos := to_3d(p.global_position)
		pos.y = AIR_HEIGHT * 0.6
		pickup_mm.set_instance_transform(pickup_count, Transform3D(Basis(), pos))
		pickup_count += 1
	pickup_mm.visible_instance_count = pickup_count


func _on_fx(kind: String, pos: Vector2, size: float) -> void:
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	var radius := (0.35 if kind == "explosion" else 0.08) * size
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.65, 0.25, 0.95) if kind == "explosion" else Color(1.0, 0.95, 0.7, 0.9)
	material.disable_fog = true
	mesh.material = material
	flash.mesh = mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := to_3d(pos)
	p.y = AIR_HEIGHT * 0.8
	flash.position = p
	add_child(flash)
	var duration := 0.45 if kind == "explosion" else 0.15
	var tween := flash.create_tween().set_parallel()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.4, duration)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(flash.queue_free)


# --- Камера и ощущение полёта ------------------------------------------------

## Камера едет за игроком по горизонтали и чуть кренится вместе с ним.
func _update_camera(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var target_x := to_3d(player.global_position).x * CAMERA_FOLLOW_SHARE
	var follow := 1.0 - exp(-CAMERA_FOLLOW * delta)
	var position_now := _camera.position
	position_now.x = lerpf(position_now.x, target_x, follow)
	_camera.position = Vector3(position_now.x, CAMERA_OFFSET.y, CAMERA_OFFSET.z)
	_camera.look_at(_camera.position + CAMERA_LOOK)
	var bank: float = player.get("visual_bank") if player.get("visual_bank") != null else 0.0
	_camera_roll = lerpf(_camera_roll, -bank * 0.05, follow)
	_camera.rotate_object_local(Vector3.FORWARD, _camera_roll)


func _build_streaks() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.015, 0.015, 1.4)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 1, 1, 0.18)
	mesh.material = material
	_streaks = _make_multimesh(mesh)
	for i in 40:
		_streak_positions.append(_random_streak(randf_range(-40.0, 12.0)))


func _random_streak(z: float) -> Vector3:
	return Vector3(randf_range(-9.0, 9.0), randf_range(1.5, 5.5), z)


func _move_streaks(delta: float) -> void:
	var multimesh := _streaks.multimesh
	var speed := _scroll_speed * S * 6.0
	for i in _streak_positions.size():
		var p := _streak_positions[i]
		p.z += speed * delta
		if p.z > 12.0:
			p = _random_streak(-40.0)
		_streak_positions[i] = p
		multimesh.set_instance_transform(i, Transform3D(Basis(), p))
	multimesh.visible_instance_count = _streak_positions.size()


# --- Управление ----------------------------------------------------------------

## Палец двигает корабль 1:1 и в перспективе: сколько экранных пикселей
## приходится на пиксель мира возле корабля игрока.
func _update_drag_scale() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var a := to_3d(player.global_position)
	a.y = AIR_HEIGHT
	var b := to_3d(player.global_position + Vector2(100.0, 0.0))
	b.y = AIR_HEIGHT
	var pixels := _camera.unproject_position(a).distance_to(_camera.unproject_position(b))
	if pixels > 0.0:
		Arena.drag_scale_override = pixels / 100.0
