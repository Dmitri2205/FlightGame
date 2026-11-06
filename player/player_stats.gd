class_name PlayerStats
extends RefCounted
## Характеристики игрока: база корабля + купленные улучшения модулей.
## Собираются один раз в build() (формулы — в Balance), дальше только читаются.
## Игрок, ангар и выбор корабля берут значения отсюда.

# --- Корпус -------------------------------------------------------------------
var max_health: int
## На сколько процентов прокачка подняла здоровье над базой корабля.
var health_bonus_percent: int
var max_speed: float
var acceleration: float
var magnet_radius: float

# --- Основная пушка -----------------------------------------------------------
## Пауза между выстрелами, с.
var fire_interval: float
var main_damage: int
## Дополнительных патронов шрапнели в залпе.
var shrapnel: int
var shrapnel_damage: int

# --- Крыльевые пушки (0 стволов — не установлены) -----------------------------
var wing_guns_per_side: int
var wing_damage: int
var wing_interval: float

# --- Ракеты (0 в залпе — не установлены) --------------------------------------
var missiles_per_salvo: int
var missile_interval: float
var missile_damage: int


static func build(ship: ShipData, modules: ModuleProgress) -> PlayerStats:
	var s := PlayerStats.new()
	var armor_steps := modules.stat_total(Modules.HEALTH, ModuleStat.ARMOR)
	s.max_health = Balance.max_health(ship.base_health, armor_steps)
	s.health_bonus_percent = Balance.health_bonus_percent(armor_steps)
	s.max_speed = ship.max_speed
	s.acceleration = ship.acceleration()
	s.magnet_radius = Balance.magnet_radius(modules.stat_total(Modules.MAGNET, ModuleStat.RADIUS), ship.magnet_mult)

	s.fire_interval = Balance.main_fire_interval(modules.stat_total(Modules.MAIN_CANNON, ModuleStat.RATE), ship.fire_rate_mult)
	s.main_damage = Balance.main_damage(modules.stat_total(Modules.MAIN_CANNON, ModuleStat.DAMAGE), ship.damage_bonus)
	s.shrapnel = Balance.shrapnel(modules.tier(Modules.MAIN_CANNON))
	s.shrapnel_damage = Balance.SHRAPNEL_DAMAGE

	# Стволов на каждом крыле и ракет в залпе = уровень модуля.
	s.wing_guns_per_side = modules.tier(Modules.WING_CANNONS)
	s.wing_damage = Balance.wing_damage(modules.stat_total(Modules.WING_CANNONS, ModuleStat.DAMAGE))
	s.wing_interval = Balance.wing_fire_interval(modules.stat_total(Modules.WING_CANNONS, ModuleStat.RATE), ship.fire_rate_mult)

	s.missiles_per_salvo = modules.tier(Modules.MISSILES)
	s.missile_interval = Balance.missile_interval(modules.stat_total(Modules.MISSILES, ModuleStat.RELOAD))
	s.missile_damage = Balance.missile_damage(modules.stat_total(Modules.MISSILES, ModuleStat.DAMAGE))
	return s


## Корабль без улучшений (для сравнения кораблей).
static func base(ship: ShipData) -> PlayerStats:
	return build(ship, ModuleProgress.new())
