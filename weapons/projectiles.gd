class_name Projectiles
extends RefCounted
## Выпуск снаряда — одно место для всех стрелков (враги, босс, игрок; обычно
## через GunData.fire). Пуля или ракета берётся из Pool, получает скорость и
## урон и добавляется в контейнер снарядов уровня.


## Выпустить пулю `scene` из точки `pos` (глобальные координаты уровня).
static func spawn(scene: PackedScene, container: Node, pos: Vector2, velocity: Vector2, damage: int) -> Node2D:
	var bullet := Pool.take(scene) as Node2D
	bullet.position = pos
	bullet.velocity = velocity
	bullet.damage = damage
	container.add_child(bullet)
	return bullet
