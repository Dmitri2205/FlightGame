class_name ModuleData
extends RefCounted
## Описание модуля корабля (неизменяемые данные). Все модули — в Modules.
## У модуля есть УРОВЕНЬ (1..max_tier) и шкала из Balance.STEPS_PER_TIER
## делений внутри уровня. Деления покупаются по отдельности в характеристики
## (stats): при двух характеристиках — по 5 в каждую, при одной — 10.
## Прогресс игрока по модулям — в ModuleProgress.


## Характеристика модуля и подпись её текущего значения в ангаре.
class StatDef:
	## id из ModuleStat.
	var id: String
	## (stats: PlayerStats) -> String — текущее значение, например «урон 3».
	var describe: Callable

	func _init(stat_id: String, describe_value: Callable) -> void:
		id = stat_id
		describe = describe_value

	func title() -> String:
		return ModuleStat.title(id)


## id из Modules (ключ в сохранении — не менять).
var id: String
var title: String
var max_tier: int
## Стоит ли модуль на корабле с самого начала. Если нет — его сначала
## устанавливают за install_cost звёзд.
var installed_at_start: bool
var install_cost: int
## Цена первого деления первого уровня (рост цены — Balance.module_cost).
var base_cost: int
var stats: Array[StatDef]
## (stats: PlayerStats) -> String — что даёт уровень. Получает характеристики
## игрока с полностью заполненным этим уровнем (см. GameState.describe_tier).
var describe_tier: Callable


func _init(module_id: String, module_title: String) -> void:
	id = module_id
	title = module_title


## Сколько делений в одну характеристику на каждом уровне (5 или 10).
func steps_per_stat() -> int:
	return Balance.STEPS_PER_TIER / stats.size()


func get_stat(stat_id: String) -> StatDef:
	for stat in stats:
		if stat.id == stat_id:
			return stat
	push_error("У модуля %s нет характеристики %s" % [id, stat_id])
	return null
