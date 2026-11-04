extends Node2D
## Поверхность планеты: бесконечно прокручиваемая земля с пятнами грунта
## и декором (кратеры, скалы, кристаллы — спрайты из art/sprites/decor_*).

class Patch:
	var pos: Vector2
	var radius: float
	var color: Color

class Decor:
	var pos: Vector2
	var texture: Texture2D
	var flip: bool

const DECOR_TEXTURES := [
	preload("res://art/sprites/decor_crater.png"),
	preload("res://art/sprites/decor_crater.png"),
	preload("res://art/sprites/decor_crater_large.png"),
	preload("res://art/sprites/decor_rock.png"),
	preload("res://art/sprites/decor_rock_large_a.png"),
	preload("res://art/sprites/decor_rock_large_b.png"),
	preload("res://art/sprites/decor_rocks_small_a.png"),
	preload("res://art/sprites/decor_rocks_small_a.png"),
	preload("res://art/sprites/decor_rocks_small_b.png"),
	preload("res://art/sprites/decor_rocks_small_b.png"),
	preload("res://art/sprites/decor_crystals.png"),
	preload("res://art/sprites/decor_crystals_large.png"),
	preload("res://art/sprites/decor_meteor.png"),
]

@export var scroll_speed := 120.0
@export var base_color := Color(0.6, 0.35, 0.27)
@export var patch_count := 30
@export var decor_count := 12

var _patches: Array[Patch] = []
var _decor: Array[Decor] = []


func _ready() -> void:
	var size := get_viewport_rect().size
	for i in patch_count:
		var patch := Patch.new()
		patch.pos = Vector2(randf() * size.x, randf() * size.y)
		_randomize_patch(patch)
		_patches.append(patch)
	for i in decor_count:
		var decor := Decor.new()
		_randomize_decor(decor, randf_range(-150.0, size.y))
		_decor.append(decor)


func _process(delta: float) -> void:
	var size := get_viewport_rect().size
	for patch in _patches:
		patch.pos.y += scroll_speed * delta
		if patch.pos.y - patch.radius > size.y:
			patch.pos = Vector2(randf() * size.x, -patch.radius)
			_randomize_patch(patch)
	for decor in _decor:
		decor.pos.y += scroll_speed * delta
		if decor.pos.y - decor.texture.get_height() / 2.0 > size.y:
			_randomize_decor(decor, -randf_range(150.0, 600.0))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), base_color)
	for patch in _patches:
		draw_circle(patch.pos, patch.radius, patch.color)
	for decor in _decor:
		var size := decor.texture.get_size()
		var rect := Rect2(decor.pos - size / 2.0, size)
		if decor.flip:
			rect.size.x = -rect.size.x
			rect.position.x += size.x
		draw_texture_rect(decor.texture, rect, false)


func _randomize_patch(patch: Patch) -> void:
	patch.radius = randf_range(30.0, 110.0)
	if randf() < 0.5:
		patch.color = base_color.darkened(randf_range(0.06, 0.14))
	else:
		patch.color = base_color.lightened(randf_range(0.05, 0.12))
	patch.color.a = 0.6


func _randomize_decor(decor: Decor, y: float) -> void:
	decor.texture = DECOR_TEXTURES.pick_random()
	decor.pos = Vector2(randf() * get_viewport_rect().size.x, y)
	decor.flip = randf() < 0.5
