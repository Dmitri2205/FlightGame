class_name Modules
extends RefCounted
## Единая точка доступа к модулям корабля. Порядок = порядок карточек в ангаре.
## id модулей — ключи в сохранении, не менять.

const MAIN_CANNON := "main_cannon"
const WING_CANNONS := "wing_cannons"
const MISSILES := "missiles"
const HEALTH := "health"
const MAGNET := "magnet"

static var _all: Array[ModuleData] = []


static func all() -> Array[ModuleData]:
	if _all.is_empty():
		_all = _build()
	return _all


static func get_by_id(id: String) -> ModuleData:
	for module in all():
		if module.id == id:
			return module
	push_error("Неизвестный модуль: %s" % id)
	return null


static func _build() -> Array[ModuleData]:
	const StatDef := ModuleData.StatDef

	var main := ModuleData.new(MAIN_CANNON, "Основная пушка")
	main.max_tier = 5
	main.installed_at_start = true
	main.base_cost = 30
	main.stats = [
		StatDef.new(ModuleStat.DAMAGE, func(s: PlayerStats) -> String: return "урон %d" % s.main_damage),
		StatDef.new(ModuleStat.RATE, func(s: PlayerStats) -> String: return "%.1f выстр/с" % (1.0 / s.fire_interval)),
	]
	main.describe_tier = func(s: PlayerStats) -> String:
		return "шрапнель: %d" % s.shrapnel if s.shrapnel > 0 else "один ствол"
	# Шрапнель задана на каждый уровень пушки (и на 0).
	assert(Balance.SHRAPNEL_BY_TIER.size() == main.max_tier + 1)

	var wings := ModuleData.new(WING_CANNONS, "Крыльевые пушки")
	wings.max_tier = 3
	wings.install_cost = 300
	wings.base_cost = 45
	wings.stats = [
		StatDef.new(ModuleStat.DAMAGE, func(s: PlayerStats) -> String: return "урон %d" % s.wing_damage),
		StatDef.new(ModuleStat.RATE, func(s: PlayerStats) -> String: return "раз в %.1f с" % s.wing_interval),
	]
	wings.describe_tier = func(s: PlayerStats) -> String: return "%d ств. на крыло" % s.wing_guns_per_side

	var missiles := ModuleData.new(MISSILES, "Ракеты")
	missiles.max_tier = 4
	missiles.install_cost = 600
	missiles.base_cost = 60
	missiles.stats = [
		StatDef.new(ModuleStat.DAMAGE, func(s: PlayerStats) -> String: return "урон %d" % s.missile_damage),
		StatDef.new(ModuleStat.RELOAD, func(s: PlayerStats) -> String: return "раз в %.1f с" % s.missile_interval),
	]
	missiles.describe_tier = func(s: PlayerStats) -> String: return "%d ракет(ы) в залпе" % s.missiles_per_salvo

	var health := ModuleData.new(HEALTH, "Здоровье")
	health.max_tier = 5
	health.installed_at_start = true
	health.base_cost = 25
	health.stats = [
		StatDef.new(ModuleStat.ARMOR, func(s: PlayerStats) -> String:
			return "%d HP (+%d%%)" % [s.max_health, s.health_bonus_percent]),
	]
	health.describe_tier = func(s: PlayerStats) -> String: return "до +%d%% здоровья" % s.health_bonus_percent

	var magnet := ModuleData.new(MAGNET, "Магнит")
	magnet.max_tier = 3
	magnet.installed_at_start = true
	magnet.base_cost = 25
	magnet.stats = [
		StatDef.new(ModuleStat.RADIUS, func(s: PlayerStats) -> String: return "%d px" % s.magnet_radius),
	]
	magnet.describe_tier = func(s: PlayerStats) -> String: return "до %d px" % roundi(s.magnet_radius)

	return [main, wings, missiles, health, magnet]
