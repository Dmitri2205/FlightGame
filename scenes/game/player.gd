extends Area2D
## Корабль игрока: стреляет автоматически и летит к точке, которую ведёт палец.
## Движение инерционное: ускорение = тяга / масса, поэтому тяжёлый корабль
## отстаёт от пальца и проскакивает цель, а лёгкий слушается почти мгновенно.

signal health_changed(current: int, maximum: int)
signal died

@export var bullet_scene: PackedScene
@export var bullet_speed := 1400.0
@export var invulnerability_time := 1.0
## Насколько сильно корабль стремится к цели: желаемая скорость = расстояние * gain.
@export var follow_gain := 10.0
## Максимальный крен на вираже (радианы).
@export var max_bank := 0.3

## Куда складывать пули (выставляет уровень).
var projectile_container: Node

var max_health := 3
var health := 3
var magnet_radius := 60.0
var ship: ShipData
var velocity := Vector2.ZERO

var _target := Vector2.ZERO
var _max_speed := 1100.0
var _acceleration := 6000.0

var _fire_interval := 0.25
var _fire_cooldown := 0.0
var _main_damage := 1
var _wing_level := 0
var _wing_damage := 1
var _invulnerable_left := 0.0


func _ready() -> void:
	add_to_group("player")
	ship = GameState.get_selected_ship()
	_max_speed = ship.max_speed
	_acceleration = ship.acceleration()
	_apply_visuals()
	max_health = GameState.player_max_health()
	health = max_health
	magnet_radius = GameState.magnet_radius()
	_fire_interval = GameState.fire_interval()
	_main_damage = GameState.main_cannon_damage()
	_wing_level = GameState.wing_cannons_level()
	_wing_damage = GameState.wing_cannon_damage()


func _unhandled_input(event: InputEvent) -> void:
	# Мышь эмулирует тач (см. project.godot), поэтому одного обработчика достаточно.
	# Палец двигает цель 1:1, а корабль догоняет её со своей инерцией.
	if event is InputEventScreenDrag:
		_target = _clamp_point(_target + event.relative)


## Мгновенно поставить корабль в точку (старт уровня).
func place_at(pos: Vector2) -> void:
	position = pos
	_target = pos
	velocity = Vector2.ZERO


func _process(delta: float) -> void:
	# Клавиатура — для отладки на ПК.
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		_target = _clamp_point(_target + dir * _max_speed * delta)

	_move(delta)

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = _fire_interval
		_fire()

	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		visible = _invulnerable_left <= 0.0 or int(_invulnerable_left * 15.0) % 2 == 0


func take_damage(amount: int) -> void:
	if _invulnerable_left > 0.0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()
		queue_free()
	else:
		_invulnerable_left = invulnerability_time


func _fire() -> void:
	_spawn_bullet(Vector2(0, -44), Vector2.UP, _main_damage)
	if _wing_level > 0:
		var spread := 0.04 + 0.01 * _wing_level
		_spawn_bullet(Vector2(-26, -8), Vector2.UP.rotated(-spread), _wing_damage)
		_spawn_bullet(Vector2(26, -8), Vector2.UP.rotated(spread), _wing_damage)


func _spawn_bullet(offset: Vector2, direction: Vector2, damage: int) -> void:
	if bullet_scene == null or projectile_container == null:
		return
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position + offset
	bullet.velocity = direction * bullet_speed
	bullet.damage = damage
	projectile_container.add_child(bullet)


func _move(delta: float) -> void:
	var desired := ((_target - position) * follow_gain).limit_length(_max_speed)
	velocity = velocity.move_toward(desired, _acceleration * delta)
	position += velocity * delta

	var clamped := _clamp_point(position)
	if clamped.x != position.x:
		velocity.x = 0.0
	if clamped.y != position.y:
		velocity.y = 0.0
	position = clamped

	# Крен: наклон и «сжатие» силуэта по горизонтали на вираже.
	var bank := clampf(velocity.x / _max_speed, -1.0, 1.0)
	$Visual.rotation = bank * max_bank * 0.5
	$Visual.scale.x = ship.visual_scale * (1.0 - absf(bank) * 0.3)


func _apply_visuals() -> void:
	$Visual.scale = Vector2.ONE * ship.visual_scale
	$Collision.scale = Vector2.ONE * ship.visual_scale
	$Visual/Body.color = ship.color
	$Visual/Wings.color = ship.color.darkened(0.25)


func _clamp_point(point: Vector2) -> Vector2:
	var rect := get_viewport_rect()
	return Vector2(
		clampf(point.x, 30.0, rect.size.x - 30.0),
		clampf(point.y, 60.0, rect.size.y - 40.0),
	)
