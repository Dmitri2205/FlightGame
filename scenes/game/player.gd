extends Area2D
## Корабль игрока: стреляет автоматически и летит к точке, которую ведёт палец.
## Движение инерционное: ускорение = тяга / масса, поэтому тяжёлый корабль
## отстаёт от пальца и проскакивает цель, а лёгкий слушается почти мгновенно.

signal health_changed(current: int, maximum: int)
signal died

@export var bullet_scene: PackedScene
## Шрапнель основной пушки (появляется со 2-го уровня улучшения).
@export var shrapnel_scene: PackedScene
## Пули крыльевых пушек.
@export var wing_bullet_scene: PackedScene
## Самонаводящиеся ракеты (модуль «Ракеты»).
@export var missile_scene: PackedScene
@export var bullet_speed := 1400.0
@export var invulnerability_time := 1.0
## Насколько сильно корабль стремится к цели: желаемая скорость = расстояние * gain.
@export var follow_gain := 10.0
## Максимальный наклон силуэта на вираже (радианы). Нос не поворачивается:
## крен показывается сужением и перекосом силуэта, плюс лёгкий наклон.
@export var max_bank := 0.08

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
var _shrapnel := 0
var _wing_guns := 0
var _wing_damage := 1
var _wing_interval := 0.34
var _wing_cooldown := 0.0
var _missiles := 0
var _missile_interval := 2.0
var _missile_damage := 4
var _missile_cooldown := 1.0
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
	_shrapnel = GameState.shrapnel_count()
	_wing_guns = GameState.wing_guns_per_side()
	_wing_damage = GameState.wing_cannon_damage()
	_wing_interval = GameState.wing_fire_interval()
	_missiles = GameState.missiles_per_salvo()
	_missile_interval = GameState.missile_interval()
	_missile_damage = GameState.missile_damage()


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

	if _wing_guns > 0:
		_wing_cooldown -= delta
		if _wing_cooldown <= 0.0:
			_wing_cooldown = _wing_interval
			_fire_wings()

	if _missiles > 0:
		_missile_cooldown -= delta
		if _missile_cooldown <= 0.0:
			_missile_cooldown = _missile_interval
			_launch_missiles()

	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		visible = _invulnerable_left <= 0.0 or int(_invulnerable_left * 15.0) % 2 == 0


func take_damage(amount: int) -> void:
	if _invulnerable_left > 0.0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		FX.explosion(global_position, 1.8)
		died.emit()
		queue_free()
	else:
		FX.shake(10.0, 0.3)
		_invulnerable_left = invulnerability_time


## Залп. Стволы стоят там, где они у модели корабля (ShipData.nose_gun / wing_gun).
## Чем выше уровень модуля, тем больше видно стволов и патронов.
func _fire() -> void:
	if projectile_container == null:
		return
	var nose := ship.nose_gun * ship.visual_scale

	# Основная пушка — из носа.
	_spawn_bullet(bullet_scene, nose, Vector2.UP, _main_damage, bullet_speed)
	FX.muzzle(global_position + nose)

	# Шрапнель — маленькие патроны веером по бокам от основного, по очереди слева/справа.
	for i in _shrapnel:
		var side := 1.0 if i % 2 == 0 else -1.0
		var tier := i / 2
		var angle := side * (0.09 + 0.07 * tier)
		_spawn_bullet(shrapnel_scene, nose + Vector2(side * (4.0 + 3.0 * tier), 8.0), Vector2.UP.rotated(angle), 1, bullet_speed * 0.9)


## Крыльевые пушки — с крыльев, в своём темпе; 2-й и 3-й стволы расходятся веером.
func _fire_wings() -> void:
	if projectile_container == null:
		return
	if _wing_guns > 0:
		for side in [-1.0, 1.0]:
			var mount := Vector2(ship.wing_gun.x * side, ship.wing_gun.y) * ship.visual_scale
			for k in _wing_guns:
				var offset: Vector2 = mount + Vector2(side * 5.0 * k, 4.0 * k)
				_spawn_bullet(wing_bullet_scene, offset, Vector2.UP.rotated(side * (0.03 + 0.08 * k)), _wing_damage, bullet_speed)
			FX.muzzle(global_position + mount, 0.6)


## Залп ракет: по очереди слева и справа, из-под крыльев (между фюзеляжем и
## крыльевыми пушками). Ракеты стартуют в сторону и доворачивают на врагов.
func _launch_missiles() -> void:
	if projectile_container == null or missile_scene == null:
		return
	for i in _missiles:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		var mount := Vector2(ship.wing_gun.x * 0.6 * side, ship.wing_gun.y + 10.0 + 8.0 * row) * ship.visual_scale
		var missile = missile_scene.instantiate()
		missile.position = global_position + mount
		missile.velocity = Vector2.UP.rotated(side * (0.7 + 0.25 * row))
		missile.damage = _missile_damage
		projectile_container.add_child(missile)


func _spawn_bullet(scene: PackedScene, offset: Vector2, direction: Vector2, damage: int, speed: float) -> void:
	if scene == null:
		scene = bullet_scene
	var bullet = scene.instantiate()
	bullet.position = global_position + offset
	bullet.velocity = direction * speed
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

	# Крен на вираже: корабль заваливается на бок (сужение + перекос силуэта)
	# и чуть наклоняется, но нос продолжает смотреть вперёд.
	var bank := clampf(velocity.x / _max_speed, -1.0, 1.0)
	PatternMotion.apply_bank($Visual, bank, Vector2.ONE * ship.visual_scale)
	$Visual.rotation = bank * max_bank


func _apply_visuals() -> void:
	$Visual.scale = Vector2.ONE * ship.visual_scale
	$Collision.scale = Vector2.ONE * ship.visual_scale
	if ship.texture:
		$Visual/Sprite.texture = ship.texture


func _clamp_point(point: Vector2) -> Vector2:
	var rect := get_viewport_rect()
	return Vector2(
		clampf(point.x, 30.0, rect.size.x - 30.0),
		clampf(point.y, 60.0, rect.size.y - 40.0),
	)
