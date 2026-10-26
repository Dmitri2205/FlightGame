extends Area2D
## Пуля. Кого она бьёт, задаётся маской коллизий в сцене
## (player_bullet → враги, enemy_bullet → игрок).

var velocity := Vector2.ZERO
var damage := 1


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	rotation = velocity.angle() + PI / 2.0


func _process(delta: float) -> void:
	position += velocity * delta
	if not get_viewport_rect().grow(100.0).has_point(position):
		queue_free()


func _on_area_entered(area) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()
