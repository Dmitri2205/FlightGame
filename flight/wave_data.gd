class_name WaveData
extends Resource
## Волна: «паровозик» из нескольких врагов одного типа по одной траектории.
## Библиотека — flight/waves/*.tres.

enum Mirror {
	NONE,    ## как описано в траектории
	RANDOM,  ## случайная сторона
	BOTH,    ## пара с двух сторон одновременно
}

@export var title := ""
## Сцена врага (enemies/*/*.tscn).
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

## Наземная ли волна (танки, турели).
func is_ground() -> bool:
	return enemy != null and EnemyInfo.of(enemy).is_ground


## Сколько секунд выпускается вся волна (от первого врага до последнего).
func duration() -> float:
	return spawn_interval() * (count - 1)


## Через сколько секунд выпускать следующего врага «паровозика».
func spawn_interval() -> float:
	if enemy == null:
		return 0.0
	# Неподвижные наземные (турели) едут вниз только вместе с землёй.
	var speed := EnemyInfo.of(enemy).speed
	if speed <= 0.0:
		speed = Arena.GROUND_SCROLL_SPEED
	return spacing / speed
