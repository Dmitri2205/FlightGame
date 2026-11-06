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

## Шрапнель основной пушки по уровням модуля 0..5.
const SHRAPNEL_BY_TIER := [0, 0, 1, 2, 3, 4]
## +3% к базовому здоровью за каждое деление (уровень = +30%).
const HEALTH_PER_STEP := 0.03


static func max_health(base_health: int, armor_steps: int) -> int:
	return roundi(base_health * (1.0 + HEALTH_PER_STEP * armor_steps))


static func health_bonus_percent(armor_steps: int) -> int:
	return roundi(HEALTH_PER_STEP * 100 * armor_steps)


static func shrapnel(tier: int) -> int:
	return SHRAPNEL_BY_TIER[clampi(tier, 0, SHRAPNEL_BY_TIER.size() - 1)]


static func main_fire_interval(rate_steps: int, fire_rate_mult: float) -> float:
	return 0.25 * pow(0.97, rate_steps) / fire_rate_mult


static func main_damage(damage_steps: int, ship_bonus: int) -> int:
	return 1 + damage_steps / 3 + ship_bonus


static func wing_damage(damage_steps: int) -> int:
	return 8 + damage_steps


static func wing_fire_interval(rate_steps: int, fire_rate_mult: float) -> float:
	return 2.4 * pow(0.97, rate_steps) / fire_rate_mult


static func missile_interval(reload_steps: int) -> float:
	return 2.2 * pow(0.95, reload_steps)


static func missile_damage(damage_steps: int) -> int:
	return 4 + damage_steps / 2


static func magnet_radius(radius_steps: int, magnet_mult: float) -> float:
	return (60.0 + 10.0 * radius_steps) * magnet_mult
