class_name Progress
extends RefCounted
## Игровой прогресс — то, что стирает «Сбросить прогресс». Новый экземпляр =
## начало игры. Сохраняется вместе с Settings в один save.json (ключи не менять:
## по ним читаются старые сохранения). Правила изменения — в GameState.

var stars := 0
## Кристаллы — редкая («твёрдая») валюта: докупка чертежей, потом — ускорения.
var crystals := 0
## Собранные чертежи кораблей: id корабля → сколько кусков.
var blueprints := {}
## Скрытая защита от невезения: сколько пройденных уровней подряд без чертежа.
var blueprint_pity := 0
var modules := ModuleProgress.new()
## Первый корабль открыт всегда.
var unlocked_ships: Array[String] = [ShipCatalog.first().id]
var selected_ship_id: String = ShipCatalog.first().id
## Пройденные уровни: "id_главы:номер_уровня" → лучший счёт.
var completed_levels := {}
## Выбранная глава (индекс в ChapterCatalog).
var current_chapter := 0


func to_dict() -> Dictionary:
	return {
		"stars": stars,
		"crystals": crystals,
		"blueprints": blueprints,
		"blueprint_pity": blueprint_pity,
		"modules": modules.to_dict(),
		"unlocked_ships": unlocked_ships,
		"selected_ship": selected_ship_id,
		"completed_levels": completed_levels,
		"current_chapter": current_chapter,
	}


## Недостающие ключи — значения нового прогресса; неизвестные корабли и главы
## не ломают загрузку.
static func from_dict(data: Dictionary) -> Progress:
	var p := Progress.new()
	p.stars = int(data.get("stars", p.stars))
	p.crystals = int(data.get("crystals", p.crystals))
	p.blueprints = data.get("blueprints", p.blueprints)
	p.blueprint_pity = int(data.get("blueprint_pity", p.blueprint_pity))
	p.modules = ModuleProgress.from_dict(data.get("modules", {}))
	for id in data.get("unlocked_ships", []):
		if not String(id) in p.unlocked_ships:
			p.unlocked_ships.append(String(id))
	var selected := String(data.get("selected_ship", p.selected_ship_id))
	if selected in p.unlocked_ships:
		p.selected_ship_id = selected
	p.completed_levels = data.get("completed_levels", p.completed_levels)
	p.current_chapter = clampi(int(data.get("current_chapter", p.current_chapter)), 0, ChapterCatalog.count() - 1)
	return p
