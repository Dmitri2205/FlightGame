@tool
class_name FlightStep
extends Resource
## Один манёвр траектории. В инспекторе видны только поля выбранного типа.

enum Type {
	LINE,   ## лететь прямо distance пикселей
	TURN,   ## повернуть на angle градусов по дуге радиуса radius
	AIM,    ## duration секунд доворачивать на игрока со скоростью turn_rate град/с
	HOVER,  ## почти зависнуть на duration секунд
}

const FIELDS := {
	Type.LINE: ["distance"],
	Type.TURN: ["angle", "radius"],
	Type.AIM: ["duration", "turn_rate"],
	Type.HOVER: ["duration"],
}

@export var type := Type.LINE:
	set(value):
		type = value
		notify_property_list_changed()
@export var distance := 300.0
## Положительный угол — против часовой стрелки на экране
## (летящий вниз враг уходит к правому краю). 360 — мёртвая петля.
@export var angle := 90.0
@export var radius := 120.0
@export var duration := 1.0
@export var turn_rate := 240.0


func _validate_property(property: Dictionary) -> void:
	if property.name in ["distance", "angle", "radius", "duration", "turn_rate"] \
			and not property.name in FIELDS[type]:
		property.usage = PROPERTY_USAGE_STORAGE
