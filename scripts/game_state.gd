extends Node
## Глобальное состояние: звёзды, уровни улучшений, сохранение.
## Подключено как autoload `GameState`.

signal stars_changed(total: int)
signal upgrade_changed(id: String, level: int)

const SAVE_PATH := "user://save.json"

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


func _ready() -> void:
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


# --- Характеристики корабля (весь баланс в одном месте) ----------------------

func player_max_health() -> int:
	return 3 + get_level("health")


func fire_interval() -> float:
	return 0.25 * pow(0.93, get_level("main_cannon"))


func main_cannon_damage() -> int:
	return 1 + get_level("main_cannon") / 3


func wing_cannons_level() -> int:
	return get_level("wing_cannons")


func wing_cannon_damage() -> int:
	return maxi(1, get_level("wing_cannons") / 2)


func magnet_radius() -> float:
	return 60.0 + 35.0 * get_level("magnet")


# --- Сохранение --------------------------------------------------------------

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить игру: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"stars": stars,
		"upgrades": upgrade_levels,
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


func reset_progress() -> void:
	stars = 0
	upgrade_levels = {}
	stars_changed.emit(stars)
	save_game()
