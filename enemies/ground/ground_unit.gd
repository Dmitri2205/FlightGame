extends Area2D
## Наземный враг: танк или турель. Стоит на земле и уезжает вниз вместе с ней
## (скорость прокрутки — у фона, группа "background"), поверх этого может
## ехать по траектории (FlightPattern, тот же редактор, что у самолётов).
## Манёвр PARK — «приехал и встал»: дальше юнит стоит на месте на земле.
##
## Самолёт игрока пролетает над ним — тарана нет (маска коллизий 0),
## но пули и ракеты по нему попадают (слой врагов).
## Стреляет, только пока он в кадре и перед игроком.

signal destroyed(enemy: Node2D)

## Признак наземного юнита (для GhostFlock: призраки тоже едут с землёй).
var is_ground := true

@export var max_hp := 6
## Скорость езды по траектории; 0 — неподвижная турель.
@export var speed := 80.0
@export var score_value := 150
@export var star_drop := 3
## 0 — не стреляет.
@export var fire_interval := 2.4
## Выстрелов в очереди и пауза между ними.
@export var burst_count := 1
@export var burst_gap := 0.15
@export var bullet_scene: PackedScene
@export var bullet_speed := 380.0
@export var bullet_damage := 20
## Откуда вылетает пуля: расстояние от центра по направлению ствола.
@export var muzzle_distance := 30.0
## Узел, который доворачивает на игрока (башня). Пусто — стреляет туда, куда смотрит корпус.
@export var turret_path: NodePath
## Скорость доворота башни, рад/с.
@export var turret_turn_rate := 2.5
@export var explosion_size := 1.0

var projectile_container: Node
var pattern: FlightPattern

var _hp := 0
var _dead := false
var _motion: PatternMotion
var _scrolled := 0.0
var _scroll_speed := 120.0
var _alive_time := 0.0
var _fire_cooldown := 0.0
var _burst_left := 0
var _turret: Node2D
var _flash_tween: Tween


func _ready() -> void:
	add_to_group("enemies")
	_hp = max_hp
	_fire_cooldown = randf_range(0.6, maxf(fire_interval, 0.6))
	if not turret_path.is_empty():
		_turret = get_node_or_null(turret_path) as Node2D
	var background := get_tree().get_first_node_in_group("background")
	if background and "scroll_speed" in background:
		_scroll_speed = background.scroll_speed
	if pattern:
		_motion = PatternMotion.new(pattern, speed, Arena.rect().size.x)
		position = _motion.position
		rotation = _motion.sprite_rotation()


func _process(delta: float) -> void:
	_alive_time += delta
	_scrolled += _scroll_speed * delta
	if _motion:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		_motion.advance(delta, player.position if player else null)
		position = _motion.position + Vector2(0, _scrolled)
		if speed > 0.0:
			rotation = _motion.sprite_rotation()
	else:
		position.y += _scroll_speed * delta

	# Уехал вниз вместе с землёй.
	if position.y > Arena.rect().size.y + 120.0 or _alive_time > 60.0:
		queue_free()
		return

	_aim(delta)
	if fire_interval > 0.0 and _can_fire():
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			if _burst_left <= 0:
				_burst_left = burst_count
			_shoot()
			_burst_left -= 1
			_fire_cooldown = burst_gap if _burst_left > 0 else fire_interval


func take_damage(amount: int) -> void:
	if _dead:
		return
	_hp -= amount
	modulate = Color(3, 3, 3)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	if _hp <= 0:
		_dead = true
		FX.explosion(global_position, explosion_size)
		destroyed.emit(self)
		queue_free()


## Башня плавно доворачивает на игрока (спрайты нарисованы стволом вниз).
func _aim(delta: float) -> void:
	if _turret == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var wanted := global_position.direction_to(player.global_position).angle() - PI / 2.0
	var current := _turret.global_rotation
	var diff := wrapf(wanted - current, -PI, PI)
	_turret.global_rotation = current + clampf(diff, -turret_turn_rate * delta, turret_turn_rate * delta)


func _can_fire() -> bool:
	# Только из видимой части мира (не из запаса по бокам за краем экрана).
	if not Arena.visible_rect().grow(-24.0).has_point(position):
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player == null or position.y < player.position.y - 60.0


## Выстрел: из башни — куда смотрит ствол; без башни (танк) — прямо в игрока.
func _shoot() -> void:
	if bullet_scene == null or projectile_container == null:
		return
	var direction := Vector2.DOWN
	if _turret:
		direction = Vector2.DOWN.rotated(_turret.global_rotation)
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			direction = global_position.direction_to(player.global_position)
	var bullet = Pool.take(bullet_scene)
	bullet.position = global_position + direction * muzzle_distance
	bullet.velocity = direction * bullet_speed
	bullet.damage = bullet_damage
	projectile_container.add_child(bullet)
	FX.muzzle(bullet.position, 0.7)
