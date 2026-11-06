class_name Boss
extends EnemyBase
## Босс (и мини-босс — та же логика, другая сцена): выплывает сверху, ходит
## из стороны в сторону и чередует атаки. На половине здоровья впадает в
## ярость: быстрее двигается и стреляет плотнее.
## Здоровье задаёт уровень (LevelData.boss_hp / ChapterData.miniboss_hp)
## через setup() — в сцене его нет.

signal health_changed(current: int, maximum: int)

enum State { ENTERING, FIGHTING }

@export_group("Появление")
## Где появляется (y, px; выше экрана) и где останавливается.
@export var spawn_y := -150.0
@export var entry_y := 260.0
## Скорость выплывания, px/с. Пока выплывает — неуязвим.
@export var entry_speed := 160.0

@export_group("Движение")
@export var move_speed := 140.0
## Не подходит к краям мира ближе, px.
@export var edge_margin := 130.0
## Покачивание вверх-вниз вокруг entry_y: частота и размах, px.
@export var bob_frequency := 1.3
@export var bob_amplitude := 30.0

@export_group("Пушки")
## Точки вылета пуль относительно центра: нос и бортовые пушки
## (у мини-босса спрайт другой — свои точки).
@export var nose := Vector2(0, 92)
@export var gun_left := Vector2(-46, 58)
@export var gun_right := Vector2(46, 58)
## Урон тарана по игроку, HP (сам босс при таране не погибает).
@export var ram_damage := 30

@export_group("Атаки")
## Пауза до первой атаки после выхода, с.
@export var first_attack_delay := 1.5
## Обычный режим: пауза между атаками, веер из носа (пуль, ширина, рад),
## бортовой залп (угол косых выстрелов, рад).
@export var calm_attack_cooldown := 1.4
@export var calm_fan_bullets := 5
@export var calm_fan_spread := 0.6
@export var side_volley_angle := 0.15
## Ярость: пауза между атаками, кольцо (пуль), широкий веер и узкий веер,
## который идёт вместе со смещённым кольцом.
@export var rage_attack_cooldown := 0.9
@export var ring_bullets := 18
@export var rage_fan_bullets := 7
@export var rage_fan_spread := 0.9
@export var combo_fan_bullets := 3
@export var combo_fan_spread := 0.3

@export_group("Ярость")
## Доля здоровья, ниже которой (включительно) босс в ярости.
@export var enrage_at := 0.5
## Во сколько раз быстрее ходит в ярости.
@export var enrage_speed_mult := 1.6
## Пауза до первой атаки сразу после впадения в ярость, с.
@export var enrage_attack_delay := 0.6
## Оттенок босса в ярости.
@export var enrage_tint := Color(1.25, 0.8, 0.8)

@export_group("Гибель")
## Серия взрывов перед финальным (сколько, в каком радиусе); финальный —
## explosion_size.
@export var death_chain := 8
@export var death_radius := 120.0

## Полное здоровье. Задаёт уровень через setup() до add_child.
var max_hp := 0

var _state := State.ENTERING
var _time := 0.0
var _dir := 1.0
var _attack_cooldown := 0.0
var _pattern := 0


## Настроить перед add_child: здоровье и точка появления по центру мира.
func setup(p_max_hp: int) -> void:
	max_hp = p_max_hp
	position = Vector2(Arena.rect().size.x / 2.0, spawn_y)


func _ready() -> void:
	assert(max_hp > 0, "Boss: здоровье задаётся через setup() до add_child")
	add_to_group("enemies")
	hp = max_hp
	_attack_cooldown = first_attack_delay
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_time += delta
	match _state:
		State.ENTERING:
			position.y = move_toward(position.y, entry_y, entry_speed * delta)
			if position.y >= entry_y:
				_state = State.FIGHTING
		State.FIGHTING:
			_move(delta)
			_attack_cooldown -= delta
			if _attack_cooldown <= 0.0:
				_attack()


func is_enraged() -> bool:
	return hp <= max_hp * enrage_at


# Пока выплывает — неуязвим, чтобы не сбить его ещё за экраном.
func _is_vulnerable() -> bool:
	return _state != State.ENTERING


func _on_damaged(previous_hp: int) -> void:
	health_changed.emit(hp, max_hp)
	var was_enraged := previous_hp <= max_hp * enrage_at
	if hp > 0 and is_enraged() and not was_enraged:
		_attack_cooldown = enrage_attack_delay


func _base_modulate() -> Color:
	return enrage_tint if is_enraged() else Color.WHITE


func _die() -> void:
	FX.chain_explosions(global_position, death_chain, death_radius)
	super()


func _move(delta: float) -> void:
	var width := Arena.rect().size.x
	var speed := move_speed * (enrage_speed_mult if is_enraged() else 1.0)
	position.x += _dir * speed * delta
	if position.x < edge_margin:
		_dir = 1.0
	elif position.x > width - edge_margin:
		_dir = -1.0
	position.y = entry_y + sin(_time * bob_frequency) * bob_amplitude


func _attack() -> void:
	if is_enraged():
		match _pattern % 3:
			0:
				_ring(0.0)
			1:
				_fan(nose, rage_fan_bullets, rage_fan_spread)
			2:
				# Кольцо, повёрнутое на полшага, — пули летят в «щели» прошлого.
				_ring(PI / ring_bullets)
				_fan(nose, combo_fan_bullets, combo_fan_spread)
		_attack_cooldown = rage_attack_cooldown
	else:
		match _pattern % 2:
			0:
				_fan(nose, calm_fan_bullets, calm_fan_spread)
			1:
				_shoot_from(gun_left, Vector2.DOWN)
				_shoot_from(gun_right, Vector2.DOWN)
				_shoot_from(gun_left, Vector2.DOWN.rotated(side_volley_angle))
				_shoot_from(gun_right, Vector2.DOWN.rotated(-side_volley_angle))
		_attack_cooldown = calm_attack_cooldown
	_pattern += 1


## Веер пуль в сторону игрока.
func _fan(offset: Vector2, count: int, spread: float) -> void:
	var origin := global_position + offset
	var player := _player()
	var aim := Vector2.DOWN
	if player:
		aim = origin.direction_to(player.global_position)
	for i in count:
		var t := 0.0 if count == 1 else float(i) / (count - 1) - 0.5
		_shoot_from(offset, aim.rotated(t * spread))


## Кольцо из ring_bullets пуль во все стороны.
func _ring(angle_offset: float) -> void:
	for i in ring_bullets:
		_shoot_from(Vector2.ZERO, Vector2.DOWN.rotated(angle_offset + TAU * i / ring_bullets))


func _shoot_from(offset: Vector2, direction: Vector2) -> void:
	_shoot(global_position + offset, direction)


func _on_area_entered(area: Area2D) -> void:
	# Таран босса бьёт игрока, но сам босс не погибает.
	if area.is_in_group("player"):
		area.take_damage(ram_damage)
