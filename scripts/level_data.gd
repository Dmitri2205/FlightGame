class_name LevelData
extends Resource
## Один уровень главы. Хранится внутри ресурса главы (chapters/*.tres).

@export var title := ""
## Длительность волн, секунд. Потом — босс (если есть) или конец уровня.
@export var duration := 60.0
## Какие волны встречаются на уровне (ключи Level.WAVES), выбираются случайно.
@export var waves := PackedStringArray()
## Пауза между волнами, секунд.
@export var spawn_interval := 2.4
## Множитель здоровья врагов (сложность).
@export var enemy_hp_mult := 1.0
@export var boss := false
@export var boss_hp := 500
## Звёзды за первое прохождение уровня.
@export var completion_bonus := 20
