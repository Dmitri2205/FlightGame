extends Sprite2D
## Тень самолёта на земле: тот же спрайт, что у самолёта, только чёрный,
## полупрозрачный, уменьшенный и сдвинутый «от солнца».
##
## Никакой отдельной отрисовки: тень берёт уже загруженную текстуру корабля
## (modulate чёрный — остаётся только силуэт по альфе). Раньше тень была
## CanvasGroup — это отдельный проход рендера на каждый самолёт, на телефоне
## дорого. Тени одного типа врагов к тому же рисуются одной пачкой.

## Куда падает тень.
@export var cast_offset := Vector2(24, 36)
## Меньше — значит самолёт выше над землёй.
@export var shadow_scale := 0.8
@export var opacity := 0.3

## Спрайт самолёта, с которого берём силуэт (первый Sprite2D у родителя).
var _source: Sprite2D


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = -5
	self_modulate = Color(0, 0, 0, opacity)


func _process(_delta: float) -> void:
	if _source == null:
		_source = _find_sprite(get_parent())
		if _source == null:
			return
	# Текстуру сверяем каждый кадр: игрок выставляет её из ShipData в _ready.
	if texture != _source.texture:
		texture = _source.texture
		centered = _source.centered
		offset = _source.offset
	visible = _source.is_visible_in_tree()
	# Повторяем положение, поворот и крен (сужение + перекос) самолёта.
	var xform := _source.global_transform
	xform.x *= shadow_scale
	xform.y *= shadow_scale
	xform.origin += cast_offset
	global_transform = xform


func _find_sprite(node: Node) -> Sprite2D:
	for child in node.get_children():
		if child == self:
			continue
		if child is Sprite2D:
			return child
		var nested := _find_sprite(child)
		if nested:
			return nested
	return null
