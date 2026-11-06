class_name GroundUnit
extends WaveEnemy
## Наземный враг: танк или турель. Стоит на земле и уезжает вниз вместе с ней
## (Arena.GROUND_SCROLL_SPEED), поверх этого может ехать по траектории
## (FlightPattern, тот же редактор, что у самолётов).
## Манёвр PARK — «приехал и встал»: дальше юнит стоит на месте на земле.
##
## Самолёт игрока пролетает над ним — тарана нет (маска коллизий 0),
## но пули и ракеты по нему попадают (слой врагов).
## Стреляет, только пока он в кадре.

@export_group("Наземный")
## Выстрелов в очереди и пауза между ними, с.
@export var burst_count := 1
@export var burst_gap := 0.15
## Откуда вылетает пуля: расстояние от центра по направлению ствола.
@export var muzzle_distance := 30.0
## Узел, который доворачивает на игрока (башня). Пусто — стреляет туда, куда смотрит корпус.
@export var turret_path: NodePath
## Скорость доворота башни, рад/с.
@export var turret_turn_rate := 2.5

## Первый выстрел — не раньше, чем через столько секунд после появления.
const FIRST_SHOT_MIN_DELAY := 0.6
## Размер вспышки у ствола.
const MUZZLE_FLASH_SIZE := 0.7

## Башня (узел turret_path) или null у танка.
var turret: Node2D

var _scrolled := 0.0
var _burst_left := 0


func _ready() -> void:
	super()
	_fire_cooldown = randf_range(FIRST_SHOT_MIN_DELAY, maxf(fire_interval, FIRST_SHOT_MIN_DELAY))
	if not turret_path.is_empty():
		turret = get_node_or_null(turret_path) as Node2D


func _process(delta: float) -> void:
	_alive_time += delta
	_scrolled += Arena.GROUND_SCROLL_SPEED * delta
	if _motion:
		_advance_motion(delta)
		position = _motion.position + Vector2(0, _scrolled)
		if speed > 0.0:
			rotation = _motion.sprite_rotation()
	else:
		position.y += Arena.GROUND_SCROLL_SPEED * delta

	if Arena.is_ground_gone(position, _alive_time):
		queue_free()
		return

	_aim(delta)
	if _can_fire():
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			if _burst_left <= 0:
				_burst_left = burst_count
			_fire()
			_burst_left -= 1
			_fire_cooldown = burst_gap if _burst_left > 0 else fire_interval


## Башня плавно доворачивает на игрока (спрайты нарисованы стволом вниз).
func _aim(delta: float) -> void:
	if turret == null:
		return
	var player := _player()
	if player == null:
		return
	var wanted := global_position.direction_to(player.global_position).angle() - PI / 2.0
	var current := turret.global_rotation
	var diff := wrapf(wanted - current, -PI, PI)
	turret.global_rotation = current + clampf(diff, -turret_turn_rate * delta, turret_turn_rate * delta)


## Выстрел: из башни — куда смотрит ствол; без башни (танк) — прямо в игрока.
func _fire() -> void:
	var direction := Vector2.DOWN
	if turret:
		direction = Vector2.DOWN.rotated(turret.global_rotation)
	else:
		var player := _player()
		if player:
			direction = global_position.direction_to(player.global_position)
	var bullet := _shoot(global_position + direction * muzzle_distance, direction)
	if bullet:
		FX.muzzle(bullet.position, MUZZLE_FLASH_SIZE)
