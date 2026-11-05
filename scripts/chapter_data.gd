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
