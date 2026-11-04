extends Area2D
## Самонаводящаяся ракета игрока. Стартует в сторону от корабля, разгоняется
## и доворачивает на ближайшего врага (группа "enemies"); если цель погибла —
## ищет новую. При попадании — урон и небольшой взрыв.

@export var start_speed := 260.0
@export var max_speed := 950.0
@export var acceleration := 1400.0
## Скорость доворота, рад/с.
@export var turn_rate := 5.0
@export var lifetime := 4.0

var velocity := Vector2.UP
var damage := 4

var _target: Node2D
var _age := 0.0
var _speed := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_speed = start_speed
	velocity = velocity.normalized() * _speed
	rotation = velocity.angle() + PI / 2.0


func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		queue_free()
		return

	if not is_instance_valid(_target):
		_target = _find_target()
	var direction := velocity.normalized()
	if _target:
		var wanted := global_position.direction_to(_target.global_position)
		var angle := direction.angle_to(wanted)
		direction = direction.rotated(clampf(angle, -turn_rate * delta, turn_rate * delta))
	_speed = minf(_speed + acceleration * delta, max_speed)
	velocity = direction * _speed
	position += velocity * delta
	rotation = velocity.angle() + PI / 2.0

	if not get_viewport_rect().grow(200.0).has_point(position):
		queue_free()


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var node := enemy as Node2D
		if node == null or not get_viewport_rect().has_point(node.global_position):
			continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


func _on_area_entered(area) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		FX.explosion(global_position, 0.45, false)
		queue_free()
