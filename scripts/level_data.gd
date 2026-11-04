class_name LevelData
extends Resource
## Один уровень главы. Хранится внутри ресурса главы (chapters/*.tres).
## Волны выпускает WaveDirector: сначала по таймлайну, плюс случайные
## наполнители. Как это выглядит — экран «Превью волн».

@export var title := ""
## Длительность волн, секунд. Потом — босс (если есть) или конец уровня.
@export var duration := 60.0

@export_group("Волны")
## Авторский сценарий: волны в заданные секунды (TimelineEntry).
@export var timeline: Array = []
## Случайные волны-наполнители (WaveData).
@export var filler_waves: Array = []
## С какой секунды начинаются наполнители.
@export var filler_from := 0.0
## Пауза между наполнителями, секунд.
@export var spawn_interval := 2.4

@export_group("Сложность")
## Множитель здоровья врагов.
@export var enemy_hp_mult := 1.0
@export var boss := false
@export var boss_hp := 500
## Звёзды за первое прохождение уровня.
@export var completion_bonus := 20
