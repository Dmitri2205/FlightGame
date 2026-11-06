class_name ChapterData
extends Resource
## Глава — отдельная планета со своим биомом и набором уровней.

@export var id := ""
@export var title := ""
@export var planet := ""
@export_multiline var description := ""
## Акцентный цвет главы в интерфейсе.
@export var color := Color.WHITE
## Цвет земли на уровнях и на карте.
@export var ground_color := Color(0.6, 0.35, 0.27)
## Текстура грунта (art/ground/*.jpg, tools/render_ground.py); пусто — заливка ground_color.
@export var ground_texture: Texture2D
## Префикс спрайтов декора: decor_ (Марс), decor_ice_, decor_toxic_ …
@export var decor_prefix := "decor_"
## Уровни главы (LevelData), по порядку прохождения.
@export var levels: Array = []

@export_group("Сила врагов")
## Множитель здоровья обычных врагов на первом уровне главы.
@export var enemy_power := 1.0
## Прибавка к множителю за каждый следующий уровень главы.
@export var power_per_level := 0.0
## Здоровье мини-босса на первом уровне главы и прибавка за каждый уровень.
@export var miniboss_hp_base := 250
@export var miniboss_hp_per_level := 30


## Множитель здоровья обычных врагов на уровне level_index (с нуля).
func enemy_hp_multiplier(level_index: int) -> float:
	return enemy_power + power_per_level * level_index


## Здоровье мини-босса на уровне level_index (с нуля).
func miniboss_hp(level_index: int) -> int:
	return miniboss_hp_base + miniboss_hp_per_level * level_index
