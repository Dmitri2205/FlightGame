class_name AirEnemy
extends WaveEnemy
## Самолёт: летит по траектории (FlightPattern), может стрелять в игрока.
## Без траектории просто летит вниз и при желании виляет (sway_*).
## Разные типы самолётов — это разные сцены с другими параметрами.

@export_group("Самолёт")
## Виляние без траектории: размах, px, и частота.
@export var sway_amplitude := 0.0
@export var sway_frequency := 2.0
## Урон тарана по игроку, HP (сам самолёт при таране погибает).
@export var ram_damage := 25

## Первый выстрел — не раньше, чем через столько секунд после появления.
const FIRST_SHOT_MIN_DELAY := 0.5

var _time := 0.0
var _base_x := 0.0
var _was_on_screen := false


func _ready() -> void:
	super()
	_base_x = position.x
	_time = randf() * TAU
	_fire_cooldown = randf_range(FIRST_SHOT_MIN_DELAY, maxf(fire_interval, FIRST_SHOT_MIN_DELAY))
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_time += delta
	_alive_time += delta
	if _motion == null:
		position.y += speed * delta
		if sway_amplitude > 0.0:
			position.x = _base_x + sin(_time * sway_frequency) * sway_amplitude
	else:
		_advance_motion(delta)
		position = _motion.position
		rotation = _motion.sprite_rotation()
		if has_node("Sprite"):
			PatternMotion.apply_bank($Sprite, _motion.bank)

	if Arena.is_on_screen(position):
		_was_on_screen = true
	elif Arena.is_air_gone(position, _was_on_screen, _alive_time):
		queue_free()
		return

	if _can_fire():
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown = fire_interval
			_fire()


## Прицельный выстрел в игрока (нет игрока — вниз).
func _fire() -> void:
	var player := _player()
	var direction := Vector2.DOWN
	if player:
		direction = global_position.direction_to(player.global_position)
	_shoot(global_position, direction)


func _on_area_entered(area: Area2D) -> void:
	# Таран: игрок получает урон, самолёт погибает.
	if area.is_in_group(Groups.PLAYER) and not _dead:
		area.take_damage(ram_damage)
		_die()
