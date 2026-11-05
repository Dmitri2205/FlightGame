class_name ShipData
extends Resource
## Характеристики корабля. Каждый корабль — отдельный .tres в res://ships/.

@export var id := ""
@export var title := ""
@export_multiline var description := ""
## Цена открытия в звёздах (0 — доступен сразу).
@export var cost := 0
## Сколько чертежей нужно собрать, чтобы корабль можно было купить
## (0 — без чертежей). Обычный — 10, редкий — 20, легендарный — 40.
@export var blueprints_required := 0

@export_group("Движение")
## Масса: чем больше, тем медленнее корабль разгоняется и тормозит.
@export var mass := 1.0
## Тяга двигателя. Ускорение = thrust / mass.
@export var thrust := 6000.0
@export var max_speed := 1100.0

@export_group("Бой")
## Базовое здоровье, HP. Улучшение «Здоровье» прибавляет проценты от него.
@export var base_health := 100
## Множитель скорострельности (больше — чаще стреляет).
@export var fire_rate_mult := 1.0
@export var damage_bonus := 0
@export var magnet_mult := 1.0

@export_group("Вид")
## Спрайт корабля (вид сверху, нос вверх). См. tools/render_topdown.py.
@export var texture: Texture2D
## Цвет корабля в интерфейсе (заголовок карточки, рамка выбора).
@export var color := Color(0.92, 0.2, 0.22)
@export var visual_scale := 1.0

@export_group("Орудия")
## Где стоит основная пушка (нос), px от центра спрайта (до visual_scale).
@export var nose_gun := Vector2(0, -40)
## Где стоят крыльевые пушки: x — расстояние от оси (зеркалится), y — по высоте.
@export var wing_gun := Vector2(28, 6)


func acceleration() -> float:
	return thrust / mass
