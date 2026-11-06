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
## Случайные волны-наполнители (WaveData): воздушные и наземные вперемешку,
## WaveDirector сам разделяет их по типу врага.
@export var filler_waves: Array = []
## С какой секунды начинаются наполнители.
@export var filler_from := 0.0

@export_group("Темп")
## Наполнители идут пачками: 1–3 воздушные волны подряд (между ними
## wave_gap секунд после конца предыдущей), потом передышка rest_min…rest_max,
## в которую с шансом ground_chance выезжает наземная волна.
@export var group_min := 1
@export var group_max := 3
@export var wave_gap := 0.8
@export var rest_min := 3.5
@export var rest_max := 6.0
@export_range(0.0, 1.0) var ground_chance := 0.6
## Мини-боссы: доли длительности уровня (0.5 — на середине). Пока мини-босс
## жив, время уровня стоит и новые волны не идут.
@export var miniboss_at: Array = []

@export_group("Сложность")
## Здоровье врагов и мини-боссов задаёт глава (ChapterData.enemy_hp_multiplier,
## ChapterData.miniboss_hp); здесь — только босс уровня.
@export var boss := false
@export var boss_hp := 500
## Звёзды за первое прохождение уровня.
@export var completion_bonus := 20
