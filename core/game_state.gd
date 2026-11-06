extends Node
## Глобальное состояние: звёзды, корабли, улучшения, прогресс по главам, сохранение.
## Подключено как autoload `GameState`. Сохраняемые данные лежат в двух
## объектах — progress (Progress) и settings (Settings); здесь — правила их
## изменения, сигналы и запись на диск.

signal stars_changed(total: int)
signal upgrade_changed(id: String, tier: int)
signal ship_changed(id: String)
signal chapter_changed(index: int)
signal crystals_changed(total: int)
signal blueprints_changed(ship_id: String, count: int)

const SAVE_PATH := "user://save.json"

## Старая система (до уровней модулей): по ней возвращаются потраченные звёзды.
## Замороженные данные миграции: ключи — из старого формата сохранения.
const LEGACY_UPGRADE_COSTS := {
	"health": [40, 1.3], "main_cannon": [50, 1.35], "wing_cannons": [80, 1.35],
	"magnet": [60, 1.3], "missiles": [150, 1.4],
}

## Сохраняемое состояние: прогресс (стирается сбросом) и настройки.
var progress := Progress.new()
var settings := Settings.new()

## Сколько звёзд вернули при переходе на уровни модулей (показать в ангаре один раз).
var legacy_refund := 0
var ships: Array[ShipData] = []
var chapters: Array[ChapterData] = []
## Какой уровень сейчас выбран/запущен (не сохраняется).
var current_level := 0
## Отладка: следующий запуск уровня начнётся сразу с босса.
var boss_test := false
## Отладка: волны с разными траекториями идут по очереди.
var pattern_test := false

## Временные псевдонимы только для чтения — для level/ и ui/wave_preview
## (пакет B). В пакете C читать progress.current_chapter / settings.view_3d.
var current_chapter: int:
	get:
		return progress.current_chapter
var view_3d: bool:
	get:
		return settings.view_3d


func _ready() -> void:
	ships = ShipCatalog.all()
	chapters = ChapterCatalog.all()
	load_game()
	apply_audio()


# --- Звёзды -------------------------------------------------------------------

func add_stars(amount: int) -> void:
	progress.stars += amount
	stars_changed.emit(progress.stars)
	save_game()


# --- Кристаллы и чертежи ------------------------------------------------------
## Чертёж на уровне спрятан так: при старте уровня с шансом
## blueprint_level_chance() решается, есть ли тут чертёж (и для какого
## корабля), а потом каждый разрушенный объект на земле с шансом
## Balance.BLUEPRINT_PROP_CHANCE роняет его. Подобранный чертёж засчитывается только
## при прохождении уровня. Где лежат чертежи, игроку не говорим.

## Константы и формулы — в Balance.


func add_crystals(amount: int) -> void:
	progress.crystals += amount
	crystals_changed.emit(progress.crystals)
	save_game()


func blueprint_count(ship_id: String) -> int:
	return int(progress.blueprints.get(ship_id, 0))


func blueprints_required(ship_id: String) -> int:
	return get_ship(ship_id).blueprints_required


func blueprints_complete(ship_id: String) -> bool:
	return blueprint_count(ship_id) >= blueprints_required(ship_id)


## Корабли, для которых ещё нужны чертежи (не куплены и не собраны).
func ships_needing_blueprints() -> Array:
	var result := []
	for ship in ships:
		if ship.blueprints_required > 0 and not is_ship_unlocked(ship.id) and not blueprints_complete(ship.id):
			result.append(ship.id)
	return result


## Цена одного куска чертежа в кристаллах (дороже у редких кораблей).
func blueprint_crystal_cost(ship_id: String) -> int:
	return Balance.blueprint_crystal_cost(blueprints_required(ship_id))


func add_blueprint(ship_id: String) -> void:
	progress.blueprints[ship_id] = mini(blueprint_count(ship_id) + 1, blueprints_required(ship_id))
	blueprints_changed.emit(ship_id, blueprint_count(ship_id))
	save_game()


func try_buy_blueprint(ship_id: String) -> bool:
	var cost := blueprint_crystal_cost(ship_id)
	if blueprints_complete(ship_id) or is_ship_unlocked(ship_id) or progress.crystals < cost:
		return false
	progress.crystals -= cost
	crystals_changed.emit(progress.crystals)
	add_blueprint(ship_id)
	return true


## Сколько кусков чертежей собрано всего (по всем кораблям).
func blueprints_collected_total() -> int:
	var total := 0
	for id in progress.blueprints:
		total += int(progress.blueprints[id])
	return total


## Шанс чертежа на уровне: падает с числом собранных, растёт от скрытой
## защиты от невезения.
func blueprint_level_chance() -> float:
	return Balance.blueprint_chance(blueprints_collected_total(), progress.blueprint_pity)


## Бросок при старте уровня: id корабля, чей чертёж тут спрятан, или "".
func roll_level_blueprint() -> String:
	var candidates := ships_needing_blueprints()
	if candidates.is_empty() or randf() >= blueprint_level_chance():
		return ""
	return candidates.pick_random()


## Итог уровня по чертежам: found — id найденного (или ""), victory — пройден ли.
func finish_level_blueprint(found: String, victory: bool) -> void:
	if not victory:
		return
	if found != "":
		progress.blueprint_pity = 0
		add_blueprint(found)
	else:
		progress.blueprint_pity += 1
		save_game()


# --- Модули: покупки ----------------------------------------------------------
# Описание модулей — Modules; уровни, деления и цены — progress.modules
# (ModuleProgress). Здесь — покупки за звёзды и сигналы.

func can_buy_step(id: String, stat: String) -> bool:
	var modules := progress.modules
	return modules.is_installed(id) and not modules.stat_full(id, stat) and not modules.is_maxed(id) \
		and progress.stars >= modules.step_cost(id)


func try_install(id: String) -> bool:
	var cost := Modules.get_by_id(id).install_cost
	if progress.modules.is_installed(id) or progress.stars < cost:
		return false
	progress.stars -= cost
	progress.modules.install(id)
	_after_upgrade(id)
	return true


## Купить деление характеристики. Заполнилась шкала — модуль переходит на новый уровень.
func try_buy_step(id: String, stat: String) -> bool:
	if not can_buy_step(id, stat):
		return false
	progress.stars -= progress.modules.step_cost(id)
	progress.modules.add_step(id, stat)
	_after_upgrade(id)
	return true


func _after_upgrade(id: String) -> void:
	stars_changed.emit(progress.stars)
	upgrade_changed.emit(id, progress.modules.tier(id))
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


# --- Характеристики корабля ---------------------------------------------------
# Итог = база выбранного корабля + улучшения (улучшения общие для всех кораблей).

func player_stats() -> PlayerStats:
	return PlayerStats.build(get_selected_ship(), progress.modules)


## Текущее значение характеристики — подпись в ангаре.
func describe_stat(id: String, stat: String) -> String:
	return Modules.get_by_id(id).get_stat(stat).describe.call(player_stats())


## Что даёт уровень модуля — видимая возможность (значения в конце уровня).
func describe_tier(id: String, tier: int) -> String:
	var stats := PlayerStats.build(get_selected_ship(), progress.modules.with_tier_filled(id, tier))
	return Modules.get_by_id(id).describe_tier.call(stats)


# --- Корабли ------------------------------------------------------------------

func get_ship(id: String) -> ShipData:
	var ship := ShipCatalog.get_by_id(id)
	return ship if ship != null else ShipCatalog.first()


func get_selected_ship() -> ShipData:
	return get_ship(progress.selected_ship_id)


func is_ship_unlocked(id: String) -> bool:
	return id in progress.unlocked_ships


## Купить можно, только когда собраны все чертежи корабля.
func can_unlock_ship(id: String) -> bool:
	return not is_ship_unlocked(id) and blueprints_complete(id) and progress.stars >= get_ship(id).cost


func try_unlock_ship(id: String) -> bool:
	var ship := get_ship(id)
	if not can_unlock_ship(id):
		return false
	progress.stars -= ship.cost
	progress.unlocked_ships.append(id)
	stars_changed.emit(progress.stars)
	select_ship(id)
	return true


func select_ship(id: String) -> void:
	if not is_ship_unlocked(id):
		return
	progress.selected_ship_id = id
	ship_changed.emit(id)
	save_game()


# --- Главы и уровни -----------------------------------------------------------

func get_chapter(index: int) -> ChapterData:
	return ChapterCatalog.get_by_index(index)


func current_chapter_data() -> ChapterData:
	return get_chapter(progress.current_chapter)


func current_level_data() -> LevelData:
	var levels := current_chapter_data().levels
	return levels[clampi(current_level, 0, levels.size() - 1)]


func select_level(chapter: int, level: int) -> void:
	progress.current_chapter = chapter
	current_level = level


func select_chapter(chapter: int) -> void:
	progress.current_chapter = clampi(chapter, 0, chapters.size() - 1)
	chapter_changed.emit(progress.current_chapter)


func _level_key(chapter: int, level: int) -> String:
	return "%s:%d" % [get_chapter(chapter).id, level]


func is_level_completed(chapter: int, level: int) -> bool:
	return progress.completed_levels.has(_level_key(chapter, level))


func best_score(chapter: int, level: int) -> int:
	return int(progress.completed_levels.get(_level_key(chapter, level), 0))


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


## Записывает прохождение текущего уровня и начисляет награду за первое
## прохождение (бонус звёзд и кристаллы). Возвращает начисленное — экран
## итогов показывает это, а не считает сам.
func complete_level(score: int) -> LevelReward:
	var key := _level_key(progress.current_chapter, current_level)
	var reward := LevelReward.new()
	if not progress.completed_levels.has(key):
		reward.bonus_stars = current_level_data().completion_bonus
		reward.crystals = Balance.CRYSTALS_FIRST_CLEAR
	progress.completed_levels[key] = maxi(score, int(progress.completed_levels.get(key, 0)))
	if reward.crystals > 0:
		progress.crystals += reward.crystals
		crystals_changed.emit(progress.crystals)
	progress.stars += reward.bonus_stars
	stars_changed.emit(progress.stars)
	save_game()
	return reward


## Временная обёртка для level/level.gd (пакет B). В пакете C уровень
## переходит на complete_level() и показывает reward.crystals вместо
## своего подсчёта first_clear. Возвращает бонус звёзд.
func complete_current_level(score: int) -> int:
	return complete_level(score).bonus_stars


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
	return progress.current_chapter + 1 < chapters.size()


func select_next_level() -> void:
	if current_level + 1 < current_chapter_data().levels.size():
		current_level += 1
	elif progress.current_chapter + 1 < chapters.size():
		progress.current_chapter += 1
		current_level = 0


# --- Сохранение --------------------------------------------------------------

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить игру: %s" % FileAccess.get_open_error())
		return
	var data := progress.to_dict()
	data.merge(settings.to_dict())
	file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Файл сохранения повреждён, начинаем заново")
		return
	progress = Progress.from_dict(data)
	settings = Settings.from_dict(data)
	# Переход со старой прокачки (уровни 0..10) — возвращаем потраченные звёзды.
	# Сохраняем, только когда прочитан весь файл: иначе на диск попали бы
	# значения по умолчанию вместо ещё не прочитанных полей.
	if not data.has("modules") and data.has("upgrades"):
		legacy_refund = _legacy_refund(data.get("upgrades", {}))
		progress.stars += legacy_refund
		save_game()


func dev_tools_available() -> bool:
	return settings.dev_mode or OS.is_debug_build()


# --- Звук -------------------------------------------------------------------

## Переключатель музыки (меню паузы). Включение при нулевой громкости
## возвращает громкость по умолчанию — иначе «вкл» было бы беззвучным.
func set_music(enabled: bool) -> void:
	settings.music_on = enabled
	if enabled and settings.music_volume <= 0.0:
		settings.music_volume = Settings.DEFAULT_VOLUME
	apply_audio()
	save_game()


## Громкость музыки 0..1. Сдвинуть ползунок вверх — значит хотеть слышать
## музыку, поэтому это заодно включает её. save = false — применить сразу,
## а сохранить потом (ползунок сохраняет, когда его отпустили).
func set_music_volume(volume: float, save := true) -> void:
	settings.music_volume = clampf(volume, 0.0, 1.0)
	if settings.music_volume > 0.0:
		settings.music_on = true
	apply_audio()
	if save:
		save_game()


## Громкость эффектов 0..1 (шина SFX). save — как у set_music_volume.
func set_sfx_volume(volume: float, save := true) -> void:
	settings.sfx_volume = clampf(volume, 0.0, 1.0)
	apply_audio()
	if save:
		save_game()


func apply_audio() -> void:
	AudioBuses.apply(AudioBuses.MUSIC, settings.music_volume, not settings.music_on)
	AudioBuses.apply(AudioBuses.SFX, settings.sfx_volume)


# --- Режим разработчика --------------------------------------------------------

func set_dev_mode(enabled: bool) -> void:
	settings.dev_mode = enabled
	save_game()


## Прототип 2.5D-вида уровня (меню разработчика).
func set_view_3d(enabled: bool) -> void:
	settings.view_3d = enabled
	save_game()


## Стирает прогресс; настройки остаются.
func reset_progress() -> void:
	progress = Progress.new()
	current_level = 0
	stars_changed.emit(progress.stars)
	crystals_changed.emit(progress.crystals)
	save_game()
