class_name GunData
extends Resource
## Пушка: сцена пули, её скорость и урон. Как часто и куда стрелять —
## решает стрелок (у каждого типа своя манера стрельбы).
## У врагов пушку настраивают в сцене (tests/validate_data.gd проверяет,
## что значения заданы), поэтому значения по умолчанию пустые. Пушки игрока
## собираются в коде через create(): урон зависит от прокачки (PlayerStats).

@export var bullet_scene: PackedScene
## Скорость пули, px/с.
@export var bullet_speed := 0.0
## Урон пули по цели, HP.
@export var bullet_damage := 0


static func create(scene: PackedScene, speed: float, damage: int) -> GunData:
	var gun := GunData.new()
	gun.bullet_scene = scene
	gun.bullet_speed = speed
	gun.bullet_damage = damage
	return gun


## Выстрел из точки `pos` в направлении `direction` (единичный вектор).
func fire(container: Node, pos: Vector2, direction: Vector2) -> Node2D:
	return Projectiles.spawn(bullet_scene, container, pos, direction * bullet_speed, bullet_damage)
