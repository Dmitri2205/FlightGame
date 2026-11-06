class_name ShipCatalog
extends RefCounted
## Единая точка доступа к кораблям. Порядок = порядок в списке выбора;
## первый корабль доступен сразу. id кораблей хранятся в сохранении — не менять.

const _SHIPS := [
	preload("res://ships/falcon.tres"),
	preload("res://ships/swift.tres"),
	preload("res://ships/bastion.tres"),
	preload("res://ships/hawk.tres"),
	preload("res://ships/citadel.tres"),
]


static func all() -> Array[ShipData]:
	var result: Array[ShipData] = []
	result.assign(_SHIPS)
	return result


static func first() -> ShipData:
	return _SHIPS[0]


## Корабль по id; неизвестный id — null.
static func get_by_id(id: String) -> ShipData:
	for ship in _SHIPS:
		if ship.id == id:
			return ship
	return null
