class_name GunData
extends Resource
## Чем стреляет враг: сцена пули, её скорость и урон. Как часто и куда —
## решает сам враг (у каждого типа своя манера стрельбы).
## Значения по умолчанию пустые: каждую пушку настраивают в сцене врага
## (tests/validate_data.gd проверяет, что они заданы).

@export var bullet_scene: PackedScene
## Скорость пули, px/с.
@export var bullet_speed := 0.0
## Урон пули по игроку, HP.
@export var bullet_damage := 0


## Выстрел из точки `pos` в направлении `direction` (единичный вектор).
func fire(container: Node, pos: Vector2, direction: Vector2) -> Node2D:
	return Projectiles.spawn(bullet_scene, container, pos, direction * bullet_speed, bullet_damage)
