extends Node
## Глобальное состояние: звёзды, корабли, уровни улучшений, сохранение.
## Подключено как autoload `GameState`.

signal stars_changed(total: int)
signal upgrade_changed(id: String, level: int)
signal ship_changed(id: String)

const SAVE_PATH := "user://save.json"

## Порядок кораблей в списке выбора. Первый доступен сразу.
const SHIP_PATHS := [
	"res://ships/falcon.tres",
	"res://ships/swift.tres",
	"res://ships/bastion.tres",
]

## Описание улучшений. Цена уровня = base_cost * cost_growth ^ текущий_уровень.
const UPGRADES := {
	"health": {
		"title": "Здоровье",
		"max_level": 10,
		"base_cost": 40,
		"cost_growth": 1.3,
	},
	"main_cannon": {
		"title": "Основная пушка",
		"max_level": 10,
		"base_cost": 50,
		"cost_growth": 1.35,
	},
	"wing_cannons": {
		"title": "Крыльевые пушки",
		"max_level": 10,
		"base_cost": 80,
		"cost_growth": 1.35,
	},
	"magnet": {
		"title": "Магнит",
		"max_level": 10,
		"base_cost": 60,
		"cost_growth": 1.3,
	},
}

var stars := 0
var upgrade_levels := {}
var ships: Array[ShipData] = []
var unlocked_ships: Array = []
var selected_ship_id := ""


func _ready() -> void:
	for path in SHIP_PATHS:
		ships.append(load(path))
	_reset_ships()
	load_game()


# --- Звёзды и улучшения -------------------------------------------------------

func add_stars(amount: int) -> void:
	stars += amount
	stars_changed.emit(stars)
	save_game()


func get_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))


func get_max_level(id: String) -> int:
	return int(UPGRADES[id].max_level)


func is_maxed(id: String) -> bool:
	return get_level(id) >= get_max_level(id)


func get_upgrade_cost(id: String) -> int:
	var data: Dictionary = UPGRADES[id]
	return int(round(data.base_cost * pow(data.cost_growth, get_level(id))))


func can_upgrade(id: String) -> bool:
	return not is_maxed(id) and stars >= get_upgrade_cost(id)


func try_upgrade(id: String) -> bool:
	if not can_upgrade(id):
		return false
	stars -= get_upgrade_cost(id)
	upgrade_levels[id] = get_level(id) + 1
	stars_changed.emit(stars)
	upgrade_changed.emit(id, get_level(id))
	save_game()
	return true


# --- Корабли ------------------------------------------------------------------

func get_ship(id: String) -> ShipData:
	for ship in ships:
		if ship.id == id:
			return ship
	return ships[0]


func get_selected_ship() -> ShipData:
	return get_ship(selected_ship_id)


func is_ship_unlocked(id: String) -> bool:
	return id in unlocked_ships


func try_unlock_ship(id: String) -> bool:
	var ship := get_ship(id)
	if is_ship_unlocked(id) or stars < ship.cost:
		return false
	stars -= ship.cost
	unlocked_ships.append(id)
	stars_changed.emit(stars)
	select_ship(id)
	return true


func select_ship(id: String) -> void:
	if not is_ship_unlocked(id):
		return
	selected_ship_id = id
	ship_changed.emit(id)
	save_game()


func _reset_ships() -> void:
	unlocked_ships = [ships[0].id]
	selected_ship_id = ships[0].id


# --- Характеристики корабля (весь баланс в одном месте) ----------------------
# Итог = база выбранного корабля + улучшения (улучшения общие для всех кораблей).

func player_max_health() -> int:
	return get_selected_ship().base_health + get_level("health")


func fire_interval() -> float:
	return 0.25 * pow(0.93, get_level("main_cannon")) / get_selected_ship().fire_rate_mult


func main_cannon_damage() -> int:
	return 1 + get_level("main_cannon") / 3 + get_selected_ship().damage_bonus


func wing_cannons_level() -> int:
	return get_level("wing_cannons")


func wing_cannon_damage() -> int:
	return maxi(1, get_level("wing_cannons") / 2)


func magnet_radius() -> float:
	return (60.0 + 35.0 * get_level("magnet")) * get_selected_ship().magnet_mult


# --- Сохранение --------------------------------------------------------------

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить игру: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"stars": stars,
		"upgrades": upgrade_levels,
		"unlocked_ships": unlocked_ships,
		"selected_ship": selected_ship_id,
	}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Файл сохранения повреждён, начинаем заново")
		return
	stars = int(data.get("stars", 0))
	upgrade_levels = data.get("upgrades", {})
	for id in data.get("unlocked_ships", []):
		if not is_ship_unlocked(id):
			unlocked_ships.append(id)
	var selected: String = data.get("selected_ship", selected_ship_id)
	if is_ship_unlocked(selected):
		selected_ship_id = selected


func reset_progress() -> void:
	stars = 0
	upgrade_levels = {}
	_reset_ships()
	stars_changed.emit(stars)
	save_game()
