class_name WaveEnemy
extends EnemyBase
## Враг из волны (его выпускает WaveDirector): самолёт (AirEnemy) или
## наземный (GroundUnit). Движется по траектории FlightPattern — тем же
## расчётом PatternMotion, что и призраки в превью волн.
## Здоровье из сцены умножает глава уровня (setup()).

## Значения по умолчанию пустые: всё настраивается в сцене врага
## (tests/validate_data.gd проверяет max_hp > 0).
@export_group("Враг")
## Прочность до множителя главы, HP.
@export var max_hp := 0
## Скорость по траектории, px/с; 0 — неподвижный (турель).
@export var speed := 0.0
## Пауза между выстрелами, с; 0 — не стреляет.
@export var fire_interval := 0.0

## Траектория (уже отражённая, если нужно). Выставляет setup() до add_child.
var pattern: FlightPattern

## Крен на вираже −1..1 (для 3D-вида); без траектории — 0.
var bank: float:
	get:
		return _motion.bank if _motion else 0.0

var _motion: PatternMotion
var _alive_time := 0.0
var _fire_cooldown := 0.0


## Настроить перед add_child: траектория и множитель здоровья главы.
func setup(p_pattern: FlightPattern, hp_multiplier: float) -> void:
	pattern = p_pattern
	max_hp = ceili(max_hp * hp_multiplier)
	position = pattern.start_position(Arena.rect().size.x)


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	if pattern:
		_motion = PatternMotion.new(pattern, speed, Arena.rect().size.x)
		position = _motion.position
		rotation = _motion.sprite_rotation()


## Сдвинуть по траектории; цель манёвра AIM — игрок.
func _advance_motion(delta: float) -> void:
	var player := _player()
	_motion.advance(delta, player.position if player else null)


## Стреляет из любой точки кадра — пролетевшие мимо бьют и в спину;
## из-за края экрана не стреляет.
func _can_fire() -> bool:
	return fire_interval > 0.0 and Arena.is_in_view(position)
