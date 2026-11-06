class_name Player
extends Area2D
## Корабль игрока: стреляет автоматически и летит к точке, которую ведёт палец.
## Движение инерционное: ускорение = тяга / масса, поэтому тяжёлый корабль
## отстаёт от пальца и проскакивает цель, а лёгкий слушается почти мгновенно.
## Характеристики (здоровье, урон, темп, скорость) — в stats (PlayerStats),
## здесь — только боевое состояние: здоровье, кулдауны, неуязвимость.

signal health_changed(current: int, maximum: int)
signal died

## Отступы от краёв поля, за которые корабль не вылетает, px.
const FIELD_MARGIN_SIDE := 30.0
const FIELD_MARGIN_TOP := 60.0
const FIELD_MARGIN_BOTTOM := 40.0
## Веер шрапнели: патроны парами слева/справа, каждая пара шире предыдущей.
## Угол (рад) и смещение по X (px) первой пары и прибавка за каждую следующую.
const SHRAPNEL_ANGLE := 0.09
const SHRAPNEL_ANGLE_STEP := 0.07
const SHRAPNEL_OFFSET_X := 4.0
const SHRAPNEL_OFFSET_X_STEP := 3.0
## Шрапнель вылетает чуть позади носа, px.
const SHRAPNEL_OFFSET_Y := 8.0
## Сдвиг каждого следующего крыльевого ствола: к краю крыла (x) и назад (y), px.
const WING_BARREL_STEP := Vector2(9.0, 4.0)
## Размер вспышки крыльевых стволов относительно основной.
const WING_MUZZLE_SIZE := 0.6
## Ракеты стартуют из-под крыла: доля от расстояния крыльевой пушки до оси,
## отступ назад от неё и шаг между рядами, px.
const MISSILE_MOUNT_X_SHARE := 0.6
const MISSILE_MOUNT_Y := 10.0
const MISSILE_ROW_STEP := 8.0
## Угол старта ракеты в сторону (рад) и прибавка за каждый следующий ряд.
const MISSILE_LAUNCH_ANGLE := 0.7
const MISSILE_ROW_ANGLE_STEP := 0.25

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
## Текущий крен −1..1 (для 3D-вида).
var visual_bank := 0.0

## Куда складывать пули (выставляет уровень).
var projectile_container: Node

var ship: ShipData
## Характеристики выбранного корабля с улучшениями (собираются в _ready).
var stats: PlayerStats
var health: int
var velocity := Vector2.ZERO

## Пушки с уроном из stats (собираются в _ready): сцена пули, скорость, урон.
var _main_gun: GunData
var _shrapnel_gun: GunData
var _wing_gun: GunData

var _target := Vector2.ZERO
var _fire_cooldown := 0.0
var _wing_cooldown := 0.0
var _missile_cooldown := Balance.MISSILE_FIRST_DELAY
var _invulnerable_left := 0.0


func _ready() -> void:
	add_to_group(Groups.PLAYER)
	ship = GameState.get_selected_ship()
	stats = GameState.player_stats()
	health = stats.max_health
	_main_gun = GunData.create(bullet_scene, bullet_speed, stats.main_damage)
	_shrapnel_gun = GunData.create(shrapnel_scene, bullet_speed * Balance.SHRAPNEL_SPEED_FACTOR, stats.shrapnel_damage)
	_wing_gun = GunData.create(wing_bullet_scene, bullet_speed, stats.wing_damage)
	_apply_visuals()


func _unhandled_input(event: InputEvent) -> void:
	# Мышь эмулирует тач (см. project.godot), поэтому одного обработчика достаточно.
	# Палец двигает цель 1:1, а корабль догоняет её со своей инерцией.
	if event is InputEventScreenDrag:
		# Палец двигается по экрану, а мир отдалён — переводим в мировые единицы.
		_target = _clamp_point(_target + event.relative / Arena.drag_scale())


## Мгновенно поставить корабль в точку (старт уровня).
func place_at(pos: Vector2) -> void:
	position = pos
	_target = pos
	velocity = Vector2.ZERO


func _process(delta: float) -> void:
	# Клавиатура — для отладки на ПК.
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		_target = _clamp_point(_target + dir * stats.max_speed * delta)

	_move(delta)

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = stats.fire_interval
		_fire()

	if stats.wing_guns_per_side > 0:
		_wing_cooldown -= delta
		if _wing_cooldown <= 0.0:
			_wing_cooldown = stats.wing_interval
			_fire_wings()

	if stats.missiles_per_salvo > 0:
		_missile_cooldown -= delta
		if _missile_cooldown <= 0.0:
			_missile_cooldown = stats.missile_interval
			_launch_missiles()

	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		visible = _invulnerable_left <= 0.0 or int(_invulnerable_left * 15.0) % 2 == 0


func take_damage(amount: int) -> void:
	if _invulnerable_left > 0.0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, stats.max_health)
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
	_main_gun.fire(projectile_container, global_position + nose, Vector2.UP)
	FX.muzzle(global_position + nose)

	# Шрапнель — маленькие патроны веером по бокам от основного, по очереди слева/справа.
	for i in stats.shrapnel:
		var side := 1.0 if i % 2 == 0 else -1.0
		var pair := i / 2
		var angle := side * (SHRAPNEL_ANGLE + SHRAPNEL_ANGLE_STEP * pair)
		var offset := Vector2(side * (SHRAPNEL_OFFSET_X + SHRAPNEL_OFFSET_X_STEP * pair), SHRAPNEL_OFFSET_Y)
		_shrapnel_gun.fire(projectile_container, global_position + nose + offset, Vector2.UP.rotated(angle))


## Крыльевые пушки — с крыльев, в своём темпе. Все стволы бьют строго вперёд,
## параллельно: 2-й и 3-й стоят дальше к краю крыла (без веера, иначе на
## 3-м уровне корабль накрывает огнём полэкрана).
func _fire_wings() -> void:
	if projectile_container == null:
		return
	for side in [-1.0, 1.0]:
		var mount := Vector2(ship.wing_gun.x * side, ship.wing_gun.y) * ship.visual_scale
		for k in stats.wing_guns_per_side:
			var offset: Vector2 = mount + Vector2(side * WING_BARREL_STEP.x * k, WING_BARREL_STEP.y * k)
			_wing_gun.fire(projectile_container, global_position + offset, Vector2.UP)
		FX.muzzle(global_position + mount, WING_MUZZLE_SIZE)


## Залп ракет: по очереди слева и справа, из-под крыльев (между фюзеляжем и
## крыльевыми пушками). Ракеты стартуют в сторону и доворачивают на врагов.
func _launch_missiles() -> void:
	if projectile_container == null or missile_scene == null:
		return
	for i in stats.missiles_per_salvo:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		var mount := Vector2(ship.wing_gun.x * MISSILE_MOUNT_X_SHARE * side, ship.wing_gun.y + MISSILE_MOUNT_Y + MISSILE_ROW_STEP * row) * ship.visual_scale
		# Скорость ракета задаёт себе сама (start_speed), отсюда — только направление.
		var direction := Vector2.UP.rotated(side * (MISSILE_LAUNCH_ANGLE + MISSILE_ROW_ANGLE_STEP * row))
		Projectiles.spawn(missile_scene, projectile_container, global_position + mount, direction, stats.missile_damage)


func _move(delta: float) -> void:
	var desired := ((_target - position) * follow_gain).limit_length(stats.max_speed)
	velocity = velocity.move_toward(desired, stats.acceleration * delta)
	position += velocity * delta

	var clamped := _clamp_point(position)
	if clamped.x != position.x:
		velocity.x = 0.0
	if clamped.y != position.y:
		velocity.y = 0.0
	position = clamped

	# Крен на вираже: корабль заваливается на бок (сужение + перекос силуэта)
	# и чуть наклоняется, но нос продолжает смотреть вперёд.
	var bank := clampf(velocity.x / stats.max_speed, -1.0, 1.0)
	visual_bank = bank
	# Спрайт игрока нарисован носом вверх, а враги — носом вниз, поэтому
	# перекос у игрока зеркальный: летим вправо — нос заваливается вправо,
	# в сторону виража (как и наклон ниже), а не против него.
	PatternMotion.apply_bank($Visual, -bank, Vector2.ONE * ship.visual_scale)
	$Visual.rotation = bank * max_bank


func _apply_visuals() -> void:
	$Visual.scale = Vector2.ONE * ship.visual_scale
	$Collision.scale = Vector2.ONE * ship.visual_scale
	if ship.texture:
		$Visual/Sprite.texture = ship.texture


func _clamp_point(point: Vector2) -> Vector2:
	var rect := Arena.rect()
	return Vector2(
		clampf(point.x, FIELD_MARGIN_SIDE, rect.size.x - FIELD_MARGIN_SIDE),
		clampf(point.y, FIELD_MARGIN_TOP, rect.size.y - FIELD_MARGIN_BOTTOM),
	)
