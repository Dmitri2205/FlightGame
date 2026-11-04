extends Node2D
## Облака над полем боя. Летят быстрее земли — получается глубина (параллакс).

class Cloud:
	var pos: Vector2
	var blobs: Array[Vector3] = []  # x, y — смещение пятна, z — радиус

@export var scroll_speed := 320.0
@export var cloud_count := 4
@export var opacity := 0.16

var _clouds: Array[Cloud] = []
var _texture: GradientTexture2D


func _ready() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	_texture = GradientTexture2D.new()
	_texture.gradient = gradient
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)

	var size := get_viewport_rect().size
	for i in cloud_count:
		var cloud := Cloud.new()
		_reset(cloud, randf() * size.y)
		_clouds.append(cloud)


func _process(delta: float) -> void:
	var size := get_viewport_rect().size
	for cloud in _clouds:
		cloud.pos.y += scroll_speed * delta
		if cloud.pos.y > size.y + 300.0:
			_reset(cloud, -300.0 - randf() * 600.0)
	queue_redraw()


func _draw() -> void:
	var tint := Color(1, 1, 1, opacity)
	for cloud in _clouds:
		for blob in cloud.blobs:
			var radius := blob.z
			var rect := Rect2(cloud.pos + Vector2(blob.x, blob.y) - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
			draw_texture_rect(_texture, rect, false, tint)


func _reset(cloud: Cloud, y: float) -> void:
	cloud.pos = Vector2(randf() * get_viewport_rect().size.x, y)
	cloud.blobs.clear()
	for i in randi_range(4, 7):
		cloud.blobs.append(Vector3(randf_range(-140, 140), randf_range(-60, 60), randf_range(70, 150)))
