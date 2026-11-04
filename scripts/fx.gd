extends Node
## Визуальные эффекты: взрывы, искры попаданий, тряска экрана.
## Подключено как autoload `FX`, вызывается откуда угодно: FX.explosion(pos).

const EXPLOSION := preload("res://scenes/fx/explosion.tscn")
const HIT_SPARK := preload("res://scenes/fx/hit_spark.tscn")
const MUZZLE_FLASH := preload("res://scenes/fx/muzzle_flash.tscn")


## Взрыв размера `size` (1 — истребитель, 2+ — крупные цели).
func explosion(pos: Vector2, size := 1.0) -> void:
	_spawn(EXPLOSION, pos, size)
	shake(3.0 * size, 0.15 + 0.08 * size)


## Серия взрывов в радиусе `radius` вокруг точки — для босса.
func chain_explosions(pos: Vector2, count: int, radius: float, size := 1.2) -> void:
	for i in count:
		var offset := Vector2(randf_range(-radius, radius), randf_range(-radius * 0.6, radius * 0.6))
		get_tree().create_timer(i * 0.12, false).timeout.connect(explosion.bind(pos + offset, size))


## Искры попадания пули.
func hit(pos: Vector2) -> void:
	_spawn(HIT_SPARK, pos, 1.0)


## Вспышка у ствола при выстреле.
func muzzle(pos: Vector2, size := 1.0) -> void:
	_spawn(MUZZLE_FLASH, pos, size)


## Тряска камеры уровня (если она есть).
func shake(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(strength, duration)


func _spawn(scene: PackedScene, pos: Vector2, size: float) -> void:
	var layer := get_tree().get_first_node_in_group("fx_layer")
	if layer == null:
		layer = get_tree().current_scene
	if layer == null:
		return
	var fx = scene.instantiate()
	fx.position = pos
	fx.size = size
	# Эффекты часто создаются из обработчиков коллизий — добавляем отложенно.
	layer.add_child.call_deferred(fx)
