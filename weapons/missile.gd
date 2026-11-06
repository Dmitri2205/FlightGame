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


## Ракеты переиспользуются через Pool (как пули): берутся Pool.take(),
## возвращаются Pool.release(). Сброс на каждый пуск — в _enter_tree.
var _spent := false


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _enter_tree() -> void:
	_spent = false
	_age = 0.0
	_target = null
	_speed = start_speed
	velocity = velocity.normalized() * _speed
	rotation = velocity.angle() + PI / 2.0
	for child in get_children():
		if child is CPUParticles2D:
			child.restart()


func _process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age > lifetime:
		_spend()
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

	if not Arena.rect().grow(200.0).has_point(position):
		_spend()


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var node := enemy as Node2D
		if node == null or not Arena.rect().has_point(node.global_position):
			continue
		var distance := global_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


func _on_area_entered(area) -> void:
	if _spent:
		return
	if area.has_method("take_damage"):
		area.take_damage(damage)
		FX.explosion(global_position, 0.45, false)
		_spend()


func _spend() -> void:
	_spent = true
	Pool.release(self)
