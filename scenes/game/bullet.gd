extends Area2D
## Пуля. Кого она бьёт, задаётся маской коллизий в сцене
## (player_bullet → враги, enemy_bullet → игрок).
## Пули переиспользуются через Pool: берутся Pool.take(), а не instantiate(),
## и возвращаются Pool.release(), а не queue_free(). Поэтому всё, что
## сбрасывается на каждый выстрел, — в _enter_tree, а не в _ready.

var velocity := Vector2.ZERO
var damage := 1

## Уже попала (или улетела) — до возврата в пул больше никого не бьёт.
var _spent := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _enter_tree() -> void:
	_spent = false
	rotation = velocity.angle() + PI / 2.0


func _process(delta: float) -> void:
	if _spent:
		return
	position += velocity * delta
	if not get_viewport_rect().grow(100.0).has_point(position):
		_spend()


func _on_area_entered(area) -> void:
	if _spent:
		return
	if area.has_method("take_damage"):
		area.take_damage(damage)
		FX.hit(global_position)
		_spend()


func _spend() -> void:
	_spent = true
	Pool.release(self)
