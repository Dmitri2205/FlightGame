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
## Интервал между врагами в «паровозике», секунд.
@export var interval := 0.3
@export var mirror := Mirror.RANDOM
## Случайная точка появления по горизонтали (вместо start.x траектории).
@export var random_x := false
