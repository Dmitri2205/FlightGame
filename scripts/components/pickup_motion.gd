class_name PickupMotion
extends Node
## Общее движение подбираемых предметов: разлёт при появлении, плавное
## падение вниз, полёт к игроку и сбор при касании.
## Вешается дочерним узлом на Area2D-подбор; двигает родителя.

signal collected

## Начальный разлёт: X в [-burst_spread_x, burst_spread_x], Y в [burst_min_y, burst_max_y].
@export var burst_spread_x := 180.0
@export var burst_min_y := -280.0
@export var burst_max_y := -100.0
@export var fall_speed := 140.0
@export var fall_accel := 500.0
@export var home_speed := 900.0
## Сколько секунд после появления предмет не летит к игроку.
@export var home_delay := 0.0
## true — летит к игроку только внутри радиуса магнита; false — всегда после задержки.
@export var use_magnet := true
@export var spin_speed := 0.0
## Насколько ниже экрана предмет исчезает.
@export var despawn_margin := 40.0

var velocity := Vector2.ZERO
var age := 0.0

@onready var _body: Area2D = get_parent() as Area2D


func _ready() -> void:
	velocity = Vector2(randf_range(-burst_spread_x, burst_spread_x), randf_range(burst_min_y, burst_max_y))
	_body.area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	age += delta
	velocity = _next_velocity(delta)
	_body.position += velocity * delta
	_body.rotation += spin_speed * delta
	if _body.position.y > Arena.rect().size.y + despawn_margin:
		_body.queue_free()


func _next_velocity(delta: float) -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player and _should_home(player):
		return _body.position.direction_to(player.position) * home_speed
	return velocity.move_toward(Vector2(0.0, fall_speed), fall_accel * delta)


func _should_home(player: Node2D) -> bool:
	if age <= home_delay:
		return false
	if not use_magnet:
		return true
	var radius: float = player.get("magnet_radius")
	return _body.position.distance_to(player.position) < radius


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		collected.emit()
		_body.queue_free()
