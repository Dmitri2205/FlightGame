extends CanvasGroup
## Тень самолёта на земле: силуэт родителя (все его Sprite2D и Polygon2D),
## сдвинутый «от солнца», уменьшенный и полупрозрачный.
## CanvasGroup рисует силуэт целиком, поэтому перекрытия частей не темнее остальной тени.

@export var offset := Vector2(24, 36)
## Меньше — значит самолёт выше над землёй.
@export var shadow_scale := 0.8
@export var opacity := 0.3

var _built := false


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = -5
	modulate = Color(0, 0, 0, opacity)


func _process(_delta: float) -> void:
	var parent := get_parent() as Node2D
	if not _built:
		_build(parent)
	global_position = parent.global_position + offset
	global_rotation = parent.global_rotation
	scale = Vector2.ONE * shadow_scale


## Копирует силуэт при первом кадре, когда родитель уже настроил свои размеры.
func _build(parent: Node2D) -> void:
	_built = true
	var to_parent := parent.global_transform.affine_inverse()
	for source in _collect_shapes(parent):
		var copy: Node2D
		var sprite := source as Sprite2D
		if sprite:
			var sprite_copy := Sprite2D.new()
			sprite_copy.texture = sprite.texture
			sprite_copy.centered = sprite.centered
			sprite_copy.offset = sprite.offset
			copy = sprite_copy
		else:
			var polygon_copy := Polygon2D.new()
			polygon_copy.polygon = (source as Polygon2D).polygon
			copy = polygon_copy
		copy.transform = to_parent * source.global_transform
		add_child(copy)


func _collect_shapes(node: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child in node.get_children():
		if child == self:
			continue
		if child is Sprite2D or child is Polygon2D:
			result.append(child)
		result.append_array(_collect_shapes(child))
	return result
