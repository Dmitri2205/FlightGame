extends Area2D
## Звезда-валюта. Разлетается из сбитого врага, падает вниз,
## в радиусе магнита притягивается к игроку.

signal collected

const FALL_SPEED := 140.0
const MAGNET_SPEED := 900.0

var velocity := Vector2.ZERO


func _ready() -> void:
	velocity = Vector2(randf_range(-180.0, 180.0), randf_range(-280.0, -100.0))
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and position.distance_to(player.position) < player.magnet_radius:
		velocity = position.direction_to(player.position) * MAGNET_SPEED
	else:
		velocity = velocity.move_toward(Vector2(0, FALL_SPEED), 500.0 * delta)
	position += velocity * delta
	rotation += delta * 3.0

	if position.y > get_viewport_rect().size.y + 40.0:
		queue_free()


func _on_area_entered(area) -> void:
	if area.is_in_group("player"):
		collected.emit()
		queue_free()
