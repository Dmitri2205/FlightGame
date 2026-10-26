extends Node2D
## Временный фон: бесконечно прокручиваемые «пятна» местности.
## Заменить на тайлы / 3D-ландшафт, когда появится арт.

class Patch:
	var pos: Vector2
	var radius: float
	var color: Color

@export var scroll_speed := 120.0
@export var base_color := Color(0.55, 0.48, 0.32)
@export var patch_count := 40

var _patches: Array[Patch] = []


func _ready() -> void:
	var size := get_viewport_rect().size
	for i in patch_count:
		var patch := Patch.new()
		patch.pos = Vector2(randf() * size.x, randf() * size.y)
		_randomize(patch)
		_patches.append(patch)


func _process(delta: float) -> void:
	var size := get_viewport_rect().size
	for patch in _patches:
		patch.pos.y += scroll_speed * delta
		if patch.pos.y - patch.radius > size.y:
			patch.pos = Vector2(randf() * size.x, -patch.radius)
			_randomize(patch)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), base_color)
	for patch in _patches:
		draw_circle(patch.pos, patch.radius, patch.color)


func _randomize(patch: Patch) -> void:
	patch.radius = randf_range(20.0, 90.0)
	if randf() < 0.5:
		patch.color = Color(0.32, 0.45, 0.22, 0.7)  # трава
	else:
		patch.color = Color(0.45, 0.43, 0.40, 0.7)  # камни
