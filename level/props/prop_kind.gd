class_name PropKind
extends Resource
## Вид разрушаемой постройки: спрайт, 3D-модель, прочность, награда, взрыв.
## Каждый вид — .tres в level/props/; какие виды бывают мелкими и крупными —
## списки в сцене постройки (level/destructible.tscn).

## Очки за постройку — за каждую единицу её прочности.
const SCORE_PER_HP := 20

## Спрайт (вид сверху).
@export var texture: Texture2D
## Модель пака (models/<имя>.glb) для 3D-вида.
@export var model_3d: StringName
## Прочность, HP.
@export var hp := 0
## Сколько звёзд выпадает.
@export var stars := 0
## Размер взрыва.
@export var blast := 1.0


func score_value() -> int:
	return SCORE_PER_HP * hp
