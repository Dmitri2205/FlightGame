class_name ModuleProgress
extends RefCounted
## Прогресс игрока по модулям: уровень и купленные деления характеристик.
## Хранится как в сохранении: id модуля → {"tier": уровень (0 — не установлен),
## "steps": {id характеристики: делений на текущем уровне}}. Модуль без записи —
## в начальном состоянии (уровень 1, если стоит с начала, иначе 0).
## Описание модулей — в Modules, цены и эффекты — в Balance / PlayerStats.

var _levels := {}


static func from_dict(data: Dictionary) -> ModuleProgress:
	var progress := ModuleProgress.new()
	progress._levels = data.duplicate(true)
	return progress


func to_dict() -> Dictionary:
	return _levels.duplicate(true)


func tier(id: String) -> int:
	if _levels.has(id):
		return int(_levels[id].tier)
	return 1 if Modules.get_by_id(id).installed_at_start else 0


func is_installed(id: String) -> bool:
	return tier(id) > 0


## Куплено делений характеристики на текущем уровне.
func stat_steps(id: String, stat: String) -> int:
	if not _levels.has(id):
		return 0
	return int(_levels[id].get("steps", {}).get(stat, 0))


## Всего делений характеристики за все уровни — от этого считаются эффекты.
func stat_total(id: String, stat: String) -> int:
	var current := tier(id)
	if current <= 0:
		return 0
	return (current - 1) * Modules.get_by_id(id).steps_per_stat() + stat_steps(id, stat)


## Заполнено делений шкалы текущего уровня (по всем характеристикам).
func tier_progress(id: String) -> int:
	var total := 0
	for stat in Modules.get_by_id(id).stats:
		total += stat_steps(id, stat.id)
	return total


func is_maxed(id: String) -> bool:
	return tier(id) >= Modules.get_by_id(id).max_tier and tier_progress(id) >= Balance.STEPS_PER_TIER


func stat_full(id: String, stat: String) -> bool:
	return stat_steps(id, stat) >= Modules.get_by_id(id).steps_per_stat()


## Цена следующего деления: дороже с каждым уровнем и с каждым делением внутри уровня.
func step_cost(id: String) -> int:
	return Balance.module_cost(Modules.get_by_id(id).base_cost, maxi(tier(id), 1), tier_progress(id))


func install(id: String) -> void:
	_levels[id] = {"tier": 1, "steps": {}}


## Добавить деление. Заполнилась шкала — модуль переходит на следующий уровень
## (на последнем уровне шкала просто заполняется до конца).
func add_step(id: String, stat: String) -> void:
	var entry := _entry(id)
	entry.steps[stat] = stat_steps(id, stat) + 1
	if tier_progress(id) >= Balance.STEPS_PER_TIER and tier(id) < Modules.get_by_id(id).max_tier:
		entry.tier = tier(id) + 1
		entry.steps = {}


## Копия, где у модуля id полностью заполнен уровень tier — чтобы показать,
## что этот уровень даёт.
func with_tier_filled(id: String, filled_tier: int) -> ModuleProgress:
	var copy := ModuleProgress.from_dict(_levels)
	var steps := {}
	var module := Modules.get_by_id(id)
	for stat in module.stats:
		steps[stat.id] = module.steps_per_stat()
	copy._levels[id] = {"tier": filled_tier, "steps": steps}
	return copy


func _entry(id: String) -> Dictionary:
	if not _levels.has(id):
		_levels[id] = {"tier": tier(id), "steps": {}}
	elif not _levels[id].has("steps"):
		_levels[id].steps = {}
	return _levels[id]
