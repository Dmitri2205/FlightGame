class_name ModuleStat
extends RefCounted
## Характеристики модулей: id (ключи в сохранении — не менять) и подписи.
## У одной характеристики одна подпись, в каком бы модуле она ни стояла.

const DAMAGE := "damage"
const RATE := "rate"
const RELOAD := "reload"
const ARMOR := "armor"
const RADIUS := "radius"

const _TITLES := {
	DAMAGE: "Урон",
	RATE: "Скорострельность",
	RELOAD: "Перезарядка",
	ARMOR: "Здоровье",
	RADIUS: "Радиус",
}


static func title(stat: String) -> String:
	return _TITLES[stat]
