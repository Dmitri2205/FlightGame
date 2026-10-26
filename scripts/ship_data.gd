class_name ShipData
extends Resource
## Характеристики корабля. Каждый корабль — отдельный .tres в res://ships/.

@export var id := ""
@export var title := ""
@export_multiline var description := ""
## Цена открытия в звёздах (0 — доступен сразу).
@export var cost := 0

@export_group("Движение")
## Масса: чем больше, тем медленнее корабль разгоняется и тормозит.
@export var mass := 1.0
## Тяга двигателя. Ускорение = thrust / mass.
@export var thrust := 6000.0
@export var max_speed := 1100.0

@export_group("Бой")
@export var base_health := 3
## Множитель скорострельности (больше — чаще стреляет).
@export var fire_rate_mult := 1.0
@export var damage_bonus := 0
@export var magnet_mult := 1.0

@export_group("Вид")
@export var color := Color(0.92, 0.2, 0.22)
@export var visual_scale := 1.0


func acceleration() -> float:
	return thrust / mass
