extends Node2D
## Одноразовый эффект: запускает все частицы-потомки и вспышку, потом удаляет себя.

@export var duration := 1.5
## До какого масштаба раздувается вспышка (узел Flash, если есть).
@export var flash_scale := 3.0

var size := 1.0


func _ready() -> void:
	scale = Vector2.ONE * size
	for child in get_children():
		if child is CPUParticles2D:
			child.restart()
	var flash := get_node_or_null("Flash") as Sprite2D
	if flash:
		var tween := create_tween().set_parallel()
		tween.tween_property(flash, "scale", Vector2.ONE * flash_scale, 0.18).from(Vector2.ONE * 0.5)
		tween.tween_property(flash, "modulate:a", 0.0, 0.25)
	get_tree().create_timer(duration, false).timeout.connect(queue_free)
