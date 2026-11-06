class_name Balance
## Игровой баланс в одном месте: константы и чистые формулы (без состояния).
## Характеристики конкретных врагов/кораблей/уровней живут в экспортируемых
## свойствах сцен и ресурсов (.tscn/.tres) — здесь только общие правила.


# --- Модули: экономика улучшений ----------------------------------------------

## Делений на шкале одного уровня модуля.
const STEPS_PER_TIER := 10
## Во сколько раз шаг следующего уровня модуля дороже шага предыдущего.
const TIER_COST_GROWTH := 2.0
## Удорожание каждого следующего деления внутри уровня (+8% за деление).
const STEP_COST_GROWTH := 0.08


## Цена деления: дороже с каждым уровнем и с каждым делением внутри уровня.
## Каждый уровень вдвое дороже предыдущего — старшие уровни приходится фармить.
static func module_cost(base_cost: int, tier: int, step: int) -> int:
	return roundi(base_cost * pow(TIER_COST_GROWTH, tier - 1) * (1.0 + STEP_COST_GROWTH * step))


# --- Чертежи ------------------------------------------------------------------

## Базовый шанс, что на уровне вообще есть чертёж (пока ничего не собрано).
const BLUEPRINT_LEVEL_CHANCE := 0.1
## Множитель шанса за каждый собранный кусок (10 собрано — ×0.74, 30 — ×0.40).
const BLUEPRINT_DECAY := 0.97
## Прибавка к шансу за каждый пустой пройденный уровень (скрытая).
const BLUEPRINT_PITY_STEP := 0.02
const BLUEPRINT_LEVEL_CHANCE_MAX := 0.3
## Шанс выпасть из одного разрушенного объекта, если на уровне чертёж есть.
const BLUEPRINT_PROP_CHANCE := 0.1


## Шанс чертежа на уровне: падает с числом собранных, растёт от защиты от невезения.
static func blueprint_chance(collected: int, pity: int) -> float:
	var base := BLUEPRINT_LEVEL_CHANCE * pow(BLUEPRINT_DECAY, collected)
	return minf(base + BLUEPRINT_PITY_STEP * pity, BLUEPRINT_LEVEL_CHANCE_MAX)


## Цена одного куска чертежа в кристаллах (дороже у редких кораблей).
static func blueprint_crystal_cost(blueprints_required: int) -> int:
	return maxi(1, blueprints_required / 2)


# --- Кристаллы ----------------------------------------------------------------

const CRYSTALS_MINIBOSS := 1
const CRYSTALS_BOSS := 3
const CRYSTALS_FIRST_CLEAR := 2


# --- Характеристики игрока ----------------------------------------------------
# Аргументы — суммы купленных делений характеристики и множители корабля.
# Готовый набор характеристик собирает PlayerStats.build().

## Шрапнель основной пушки по уровням модуля 0..5 (длина = max_tier пушки + 1).
const SHRAPNEL_BY_TIER := [0, 0, 1, 2, 3, 4]
## Урон одного патрона шрапнели (от прокачки не растёт).
const SHRAPNEL_DAMAGE := 1
## Скорость шрапнели относительно основного снаряда.
const SHRAPNEL_SPEED_FACTOR := 0.9
## +3% к базовому здоровью за каждое деление (уровень = +30%).
const HEALTH_PER_STEP := 0.03

## Каждое деление «Скорострельности» сокращает паузу между выстрелами на 3%
## (общее для основной и крыльевых пушек).
const FIRE_RATE_STEP_FACTOR := 0.97
## Пауза между выстрелами основной пушки без прокачки, с.
const MAIN_FIRE_INTERVAL := 0.25
const MAIN_BASE_DAMAGE := 1
## +1 к урону основной пушки за каждые 3 деления «Урона».
const MAIN_DAMAGE_STEPS_PER_POINT := 3

## Крыльевые бьют редко, но тяжело. Пауза между залпами без прокачки, с.
const WING_FIRE_INTERVAL := 2.4
const WING_BASE_DAMAGE := 8
## +1 к урону крыльевых за каждое деление «Урона».
const WING_DAMAGE_PER_STEP := 1

## Пауза между залпами ракет без прокачки, с.
const MISSILE_INTERVAL := 2.2
## Каждое деление «Перезарядки» сокращает паузу на 5%.
const MISSILE_RELOAD_STEP_FACTOR := 0.95
const MISSILE_BASE_DAMAGE := 4
## +1 к урону ракеты за каждые 2 деления «Урона».
const MISSILE_DAMAGE_STEPS_PER_POINT := 2
## Задержка первого залпа ракет после старта уровня, с.
const MISSILE_FIRST_DELAY := 1.0

## Радиус магнита без прокачки и прибавка за деление, px (до множителя корабля).
const MAGNET_BASE_RADIUS := 60.0
const MAGNET_RADIUS_PER_STEP := 10.0


static func max_health(base_health: int, armor_steps: int) -> int:
	return roundi(base_health * (1.0 + HEALTH_PER_STEP * armor_steps))


static func health_bonus_percent(armor_steps: int) -> int:
	return roundi(HEALTH_PER_STEP * 100 * armor_steps)


static func shrapnel(tier: int) -> int:
	return SHRAPNEL_BY_TIER[clampi(tier, 0, SHRAPNEL_BY_TIER.size() - 1)]


static func main_fire_interval(rate_steps: int, fire_rate_mult: float) -> float:
	return MAIN_FIRE_INTERVAL * pow(FIRE_RATE_STEP_FACTOR, rate_steps) / fire_rate_mult


static func main_damage(damage_steps: int, ship_bonus: int) -> int:
	return MAIN_BASE_DAMAGE + damage_steps / MAIN_DAMAGE_STEPS_PER_POINT + ship_bonus


static func wing_damage(damage_steps: int) -> int:
	return WING_BASE_DAMAGE + WING_DAMAGE_PER_STEP * damage_steps


static func wing_fire_interval(rate_steps: int, fire_rate_mult: float) -> float:
	return WING_FIRE_INTERVAL * pow(FIRE_RATE_STEP_FACTOR, rate_steps) / fire_rate_mult


static func missile_interval(reload_steps: int) -> float:
	return MISSILE_INTERVAL * pow(MISSILE_RELOAD_STEP_FACTOR, reload_steps)


static func missile_damage(damage_steps: int) -> int:
	return MISSILE_BASE_DAMAGE + damage_steps / MISSILE_DAMAGE_STEPS_PER_POINT


static func magnet_radius(radius_steps: int, magnet_mult: float) -> float:
	return (MAGNET_BASE_RADIUS + MAGNET_RADIUS_PER_STEP * radius_steps) * magnet_mult
