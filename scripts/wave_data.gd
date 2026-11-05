class_name WaveData
extends Resource
## Волна: «паровозик» из нескольких врагов одного типа по одной траектории.
## Библиотека — data/waves/*.tres.

enum Mirror {
	NONE,    ## как описано в траектории
	RANDOM,  ## случайная сторона
	BOTH,    ## пара с двух сторон одновременно
}

@export var title := ""
## Сцена врага (scenes/game/enemy_*.tscn).
@export var enemy: PackedScene
@export var pattern: FlightPattern
@export_range(1, 20) var count := 4
## Расстояние между соседними врагами в «паровозике», пикселей по пути.
## Интервал выпуска считается из скорости врага (spawn_interval()),
## поэтому зазор сохраняется для любых врагов.
@export var spacing := 150.0
@export var mirror := Mirror.RANDOM
## Случайная точка появления по горизонтали (вместо start.x траектории).
@export var random_x := false

## Скорость прокрутки земли по умолчанию (как у фона уровня), px/с.
const GROUND_SCROLL := 120.0

## Скорость врага по сцене — кэш, чтобы не создавать врага каждый раз.
static var _speed_cache := {}


## Через сколько секунд выпускать следующего врага «паровозика».
func spawn_interval() -> float:
	if enemy == null:
		return 0.0
	if not _speed_cache.has(enemy):
		var node = enemy.instantiate()
		_speed_cache[enemy] = float(node.speed) if "speed" in node else 200.0
		node.free()
	# Неподвижные наземные (турели) едут вниз только вместе с землёй.
	var speed: float = _speed_cache[enemy]
	if speed <= 0.0:
		speed = GROUND_SCROLL
	return spacing / speed
