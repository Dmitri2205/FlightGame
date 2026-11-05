extends Node
## Глобальное состояние: звёзды, корабли, улучшения, прогресс по главам, сохранение.
## Подключено как autoload `GameState`.

signal stars_changed(total: int)
signal upgrade_changed(id: String, tier: int)
signal ship_changed(id: String)
signal chapter_changed(index: int)

const SAVE_PATH := "user://save.json"

## Порядок кораблей в списке выбора. Первый доступен сразу.
const SHIP_PATHS := [
	"res://ships/falcon.tres",
	"res://ships/swift.tres",
	"res://ships/bastion.tres",
]

## Главы по порядку прохождения.
const CHAPTER_PATHS := [
	"res://chapters/mars.tres",
	"res://chapters/cryos.tres",
	"res://chapters/toxida.tres",
]

## Модули корабля. У модуля есть УРОВЕНЬ (1..max_tier) и шкала из 10 делений
## внутри уровня. Деления покупаются по отдельности в характеристики (stats):
## при двух характеристиках — по 5 в каждую, при одной — 10. Когда шкала
## заполнена, модуль переходит на следующий уровень (это открывает новую
## видимую возможность: шрапнель, ствол, ракету), шкала начинается заново.
## installed = false — модуль сначала нужно установить (install_cost).
const STEPS_PER_TIER := 10
## Во сколько раз шаг следующего уровня модуля дороже шага предыдущего.
const TIER_COST_GROWTH := 2.0
const MODULES := {
	"main_cannon": {
		"title": "Основная пушка",
		"max_tier": 5,
		"installed": true,
		"stats": {"damage": "Урон", "rate": "Скорострельность"},
		"base_cost": 30,
	},
	"wing_cannons": {
		"title": "Крыльевые пушки",
		"max_tier": 3,
		"installed": false,
		"install_cost": 300,
		"stats": {"damage": "Урон", "rate": "Скорострельность"},
		"base_cost": 45,
	},
	"missiles": {
		"title": "Ракеты",
		"max_tier": 4,
		"installed": false,
		"install_cost": 600,
		"stats": {"damage": "Урон", "reload": "Перезарядка"},
		"base_cost": 60,
	},
	"health": {
		"title": "Здоровье",
		"max_tier": 5,
		"installed": true,
		"stats": {"armor": "Здоровье"},
		"base_cost": 25,
	},
	"magnet": {
		"title": "Магнит",
		"max_tier": 3,
		"installed": true,
		"stats": {"radius": "Радиус"},
		"base_cost": 25,
	},
}
## Старая система (до уровней модулей): по ней возвращаются потраченные звёзды.
const LEGACY_UPGRADE_COSTS := {
	"health": [40, 1.3], "main_cannon": [50, 1.35], "wing_cannons": [80, 1.35],
	"magnet": [60, 1.3], "missiles": [150, 1.4],
}

var stars := 0
## Прогресс модулей: id → {"tier": уровень (0 — не установлен), "steps": {stat: делений}}.
var modules := {}
## Сколько звёзд вернули при переходе на уровни модулей (показать в ангаре один раз).
var legacy_refund := 0
var ships: Array[ShipData] = []
var unlocked_ships: Array = []
var selected_ship_id := ""
var chapters: Array[ChapterData] = []
## Пройденные уровни: "id_главы:номер_уровня" → лучший счёт.
var completed_levels := {}
## Какой уровень сейчас выбран/запущен.
var current_chapter := 0
var current_level := 0
## Инструменты разработчика (превью волн, тесты) в меню. Скрыты от игрока:
## включаются 7 тапами по названию в главном меню; в отладочной сборке — всегда.
var dev_mode := false
## Отладка: следующий запуск уровня начнётся сразу с босса.
var boss_test := false
## Отладка: волны с разными траекториями идут по очереди.
var pattern_test := false


func _ready() -> void:
	for path in SHIP_PATHS:
		ships.append(load(path))
	for path in CHAPTER_PATHS:
		chapters.append(load(path))
	_reset_ships()
	load_game()


# --- Звёзды и улучшения -------------------------------------------------------

func add_stars(amount: int) -> void:
	stars += amount
	stars_changed.emit(stars)
	save_game()


# --- Модули: уровни и деления --------------------------------------------------

func module_tier(id: String) -> int:
	return int(_module(id).tier)


func module_max_tier(id: String) -> int:
	return int(MODULES[id].max_tier)


func is_installed(id: String) -> bool:
	return module_tier(id) > 0


## Сколько делений в одну характеристику на каждом уровне (5 или 10).
func steps_per_stat(id: String) -> int:
	return STEPS_PER_TIER / MODULES[id].stats.size()


## Куплено делений характеристики на текущем уровне.
func stat_steps(id: String, stat: String) -> int:
	return int(_module(id).steps.get(stat, 0))


## Всего делений характеристики за все уровни — от этого считаются эффекты.
func stat_total(id: String, stat: String) -> int:
	var tier := module_tier(id)
	if tier <= 0:
		return 0
	return (tier - 1) * steps_per_stat(id) + stat_steps(id, stat)


func tier_progress(id: String) -> int:
	var total := 0
	for stat in MODULES[id].stats:
		total += stat_steps(id, stat)
	return total


func is_maxed(id: String) -> bool:
	return module_tier(id) >= module_max_tier(id) and tier_progress(id) >= STEPS_PER_TIER


func stat_full(id: String, stat: String) -> bool:
	return stat_steps(id, stat) >= steps_per_stat(id)


func install_cost(id: String) -> int:
	return int(MODULES[id].get("install_cost", 0))


## Цена деления: дороже с каждым уровнем и с каждым делением внутри уровня.
func step_cost(id: String) -> int:
	var tier := maxi(module_tier(id), 1)
	# Каждый уровень модуля вдвое дороже предыдущего — старшие уровни
	# приходится фармить (перепроходить уровни ради звёзд).
	return roundi(MODULES[id].base_cost * pow(TIER_COST_GROWTH, tier - 1) * (1.0 + 0.08 * tier_progress(id)))


func try_install(id: String) -> bool:
	if is_installed(id) or stars < install_cost(id):
		return false
	stars -= install_cost(id)
	modules[id] = {"tier": 1, "steps": {}}
	_after_upgrade(id)
	return true


func can_buy_step(id: String, stat: String) -> bool:
	return is_installed(id) and not stat_full(id, stat) and not is_maxed(id) and stars >= step_cost(id)


## Купить деление характеристики. Заполнилась шкала — модуль переходит на новый уровень.
func try_buy_step(id: String, stat: String) -> bool:
	if not can_buy_step(id, stat):
		return false
	stars -= step_cost(id)
	var module := _module(id)
	module.steps[stat] = stat_steps(id, stat) + 1
	if tier_progress(id) >= STEPS_PER_TIER and module_tier(id) < module_max_tier(id):
		module.tier = module_tier(id) + 1
		module.steps = {}
	_after_upgrade(id)
	return true


func _module(id: String) -> Dictionary:
	if not modules.has(id):
		modules[id] = {"tier": 1 if MODULES[id].installed else 0, "steps": {}}
	return modules[id]


func _after_upgrade(id: String) -> void:
	stars_changed.emit(stars)
	upgrade_changed.emit(id, module_tier(id))
	save_game()


## Сколько звёзд было потрачено по старой системе (уровни 0..10) — вернуть.
func _legacy_refund(old_levels: Dictionary) -> int:
	var refund := 0
	for id in old_levels:
		if not LEGACY_UPGRADE_COSTS.has(id):
			continue
		var base: float = LEGACY_UPGRADE_COSTS[id][0]
		var growth: float = LEGACY_UPGRADE_COSTS[id][1]
		for i in int(old_levels[id]):
			refund += roundi(base * pow(growth, i))
	return refund


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


# --- Главы и уровни -----------------------------------------------------------

func get_chapter(index: int) -> ChapterData:
	return chapters[clampi(index, 0, chapters.size() - 1)]


func current_chapter_data() -> ChapterData:
	return get_chapter(current_chapter)


func current_level_data() -> LevelData:
	var levels := current_chapter_data().levels
	return levels[clampi(current_level, 0, levels.size() - 1)]


func select_level(chapter: int, level: int) -> void:
	current_chapter = chapter
	current_level = level


func select_chapter(chapter: int) -> void:
	current_chapter = clampi(chapter, 0, chapters.size() - 1)
	chapter_changed.emit(current_chapter)


func _level_key(chapter: int, level: int) -> String:
	return "%s:%d" % [get_chapter(chapter).id, level]


func is_level_completed(chapter: int, level: int) -> bool:
	return completed_levels.has(_level_key(chapter, level))


func best_score(chapter: int, level: int) -> int:
	return int(completed_levels.get(_level_key(chapter, level), 0))


## Первый уровень игры открыт всегда; остальные — после прохождения предыдущего
## (первый уровень главы — после последнего уровня прошлой главы).
func is_level_unlocked(chapter: int, level: int) -> bool:
	if level > 0:
		return is_level_completed(chapter, level - 1)
	if chapter == 0:
		return true
	return is_level_completed(chapter - 1, get_chapter(chapter - 1).levels.size() - 1)


func is_chapter_unlocked(chapter: int) -> bool:
	return is_level_unlocked(chapter, 0)


func is_chapter_completed(chapter: int) -> bool:
	return is_level_completed(chapter, get_chapter(chapter).levels.size() - 1)


## Записывает прохождение текущего уровня. Возвращает бонус за первое прохождение.
func complete_current_level(score: int) -> int:
	var key := _level_key(current_chapter, current_level)
	var first_time := not completed_levels.has(key)
	completed_levels[key] = maxi(score, int(completed_levels.get(key, 0)))
	var bonus := current_level_data().completion_bonus if first_time else 0
	stars += bonus
	stars_changed.emit(stars)
	save_game()
	return bonus


## Первый открытый, но ещё не пройденный уровень — [глава, уровень].
## Если пройдено всё — последний уровень последней главы.
func next_level_to_play() -> Array:
	for c in chapters.size():
		for l in get_chapter(c).levels.size():
			if is_level_unlocked(c, l) and not is_level_completed(c, l):
				return [c, l]
	return [chapters.size() - 1, get_chapter(chapters.size() - 1).levels.size() - 1]


func has_next_level() -> bool:
	if current_level + 1 < current_chapter_data().levels.size():
		return true
	return current_chapter + 1 < chapters.size()


func select_next_level() -> void:
	if current_level + 1 < current_chapter_data().levels.size():
		current_level += 1
	elif current_chapter + 1 < chapters.size():
		current_chapter += 1
		current_level = 0


# --- Характеристики корабля (весь баланс в одном месте) ----------------------
# Итог = база выбранного корабля + улучшения (улучшения общие для всех кораблей).

## Шрапнель основной пушки по уровням модуля 0..5.
const SHRAPNEL_BY_TIER := [0, 0, 1, 2, 3, 4]
## +3% к базовому здоровью за каждое деление (уровень = +30%).
const HEALTH_PER_STEP := 0.03


func player_max_health() -> int:
	return roundi(get_selected_ship().base_health * (1.0 + HEALTH_PER_STEP * stat_total("health", "armor")))


func fire_interval() -> float:
	return 0.25 * pow(0.97, stat_total("main_cannon", "rate")) / get_selected_ship().fire_rate_mult


func main_cannon_damage() -> int:
	return 1 + stat_total("main_cannon", "damage") / 3 + get_selected_ship().damage_bonus


## Сколько дополнительных маленьких патронов (шрапнели) даёт основная пушка.
func shrapnel_count() -> int:
	return SHRAPNEL_BY_TIER[clampi(module_tier("main_cannon"), 0, SHRAPNEL_BY_TIER.size() - 1)]


## Стволов на каждом крыле = уровень модуля (0 — не установлены).
func wing_guns_per_side() -> int:
	return module_tier("wing_cannons")


func wing_cannon_damage() -> int:
	return 1 + stat_total("wing_cannons", "damage") / 3


## Свой темп у крыльевых пушек (характеристика «Скорострельность»).
func wing_fire_interval() -> float:
	return 0.34 * pow(0.96, stat_total("wing_cannons", "rate")) / get_selected_ship().fire_rate_mult


## Ракет в залпе = уровень модуля (0 — не установлены).
func missiles_per_salvo() -> int:
	return module_tier("missiles")


func missile_interval() -> float:
	return 2.2 * pow(0.95, stat_total("missiles", "reload"))


func missile_damage() -> int:
	return 4 + stat_total("missiles", "damage") / 2


func magnet_radius() -> float:
	return (60.0 + 10.0 * stat_total("magnet", "radius")) * get_selected_ship().magnet_mult


## Текущее значение характеристики — подпись в ангаре.
func describe_stat(id: String, stat: String) -> String:
	match [id, stat]:
		["main_cannon", "damage"]:
			return "урон %d" % main_cannon_damage()
		["main_cannon", "rate"]:
			return "%.1f выстр/с" % (1.0 / fire_interval())
		["wing_cannons", "damage"]:
			return "урон %d" % wing_cannon_damage()
		["wing_cannons", "rate"]:
			return "%.1f выстр/с" % (1.0 / wing_fire_interval())
		["missiles", "damage"]:
			return "урон %d" % missile_damage()
		["missiles", "reload"]:
			return "раз в %.1f с" % missile_interval()
		["health", "armor"]:
			return "%d HP (+%d%%)" % [player_max_health(), roundi(HEALTH_PER_STEP * 100 * stat_total("health", "armor"))]
		["magnet", "radius"]:
			return "%d px" % magnet_radius()
	return ""


## Что открывает уровень модуля — видимая возможность.
func describe_tier(id: String, tier: int) -> String:
	match id:
		"main_cannon":
			var shrapnel: int = SHRAPNEL_BY_TIER[clampi(tier, 0, SHRAPNEL_BY_TIER.size() - 1)]
			return "шрапнель: %d" % shrapnel if shrapnel > 0 else "один ствол"
		"wing_cannons":
			return "%d ств. на крыло" % tier
		"missiles":
			return "%d ракет(ы) в залпе" % tier
		"health":
			return "до +%d%% здоровья" % (tier * 30)
		"magnet":
			return "до %d px" % roundi(60 + 10 * tier * steps_per_stat(id))
	return ""


# --- Сохранение --------------------------------------------------------------

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить игру: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({
		"stars": stars,
		"modules": modules,
		"unlocked_ships": unlocked_ships,
		"selected_ship": selected_ship_id,
		"completed_levels": completed_levels,
		"current_chapter": current_chapter,
		"dev_mode": dev_mode,
	}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Файл сохранения повреждён, начинаем заново")
		return
	stars = int(data.get("stars", 0))
	modules = data.get("modules", {})
	# Переход со старой прокачки (уровни 0..10) — возвращаем потраченные звёзды.
	if not data.has("modules") and data.has("upgrades"):
		legacy_refund = _legacy_refund(data.get("upgrades", {}))
		stars += legacy_refund
		save_game()
	for id in data.get("unlocked_ships", []):
		if not is_ship_unlocked(id):
			unlocked_ships.append(id)
	var selected: String = data.get("selected_ship", selected_ship_id)
	if is_ship_unlocked(selected):
		selected_ship_id = selected
	completed_levels = data.get("completed_levels", {})
	current_chapter = clampi(int(data.get("current_chapter", 0)), 0, chapters.size() - 1)
	dev_mode = bool(data.get("dev_mode", false))


func dev_tools_available() -> bool:
	return dev_mode or OS.is_debug_build()


func set_dev_mode(enabled: bool) -> void:
	dev_mode = enabled
	save_game()


func reset_progress() -> void:
	stars = 0
	modules = {}
	completed_levels = {}
	current_chapter = 0
	current_level = 0
	_reset_ships()
	stars_changed.emit(stars)
	save_game()
