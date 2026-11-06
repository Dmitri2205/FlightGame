extends Node
## Визуальные эффекты: взрывы, искры попаданий, тряска экрана.
## Подключено как autoload `FX`, вызывается откуда угодно: FX.explosion(pos).
##
## Все эффекты живут в пуле: отыгравший эффект прячется и ждёт следующего
## вызова, а не пересоздаётся. Одновременно каждого вида не больше лимита
## (LIMITS) — лишние пропускаются: в куче вспышек разницы не видно, а кадр
## не проседает. У взрывов лимит большой, чтобы гибель врага не осталась без взрыва.

## Эффект появился (для 3D-вида: он рисует свой взрыв/искры там же).
signal spawned(kind: Kind, pos: Vector2, size: float)

## Виды эффектов, о которых сообщает сигнал spawned.
enum Kind { EXPLOSION, HIT }

const EXPLOSION := preload("res://fx/explosion.tscn")
const HIT_SPARK := preload("res://fx/hit_spark.tscn")
const MUZZLE_FLASH := preload("res://fx/muzzle_flash.tscn")

## Сколько эффектов вида может играть одновременно.
const LIMITS := {EXPLOSION: 32, HIT_SPARK: 16, MUZZLE_FLASH: 16}

## Слой эффектов, для которого собраны пулы (меняется вместе со сценой).
var _layer: Node
## Сцена → свободные (спрятанные) эффекты.
var _idle := {}
## Сцена → сколько эффектов этого вида сейчас играет.
var _busy := {}


## Взрыв размера `size` (1 — истребитель, 2+ — крупные цели).
## shake_screen = false — без тряски (частые мелкие взрывы, например ракеты).
func explosion(pos: Vector2, size := 1.0, shake_screen := true) -> void:
	spawned.emit(Kind.EXPLOSION, pos, size)
	_spawn_pooled(EXPLOSION, pos, size)
	if shake_screen:
		shake(3.0 * size, 0.15 + 0.08 * size)


## Серия взрывов в радиусе `radius` вокруг точки — для босса.
func chain_explosions(pos: Vector2, count: int, radius: float, size := 1.2) -> void:
	for i in count:
		var offset := Vector2(randf_range(-radius, radius), randf_range(-radius * 0.6, radius * 0.6))
		get_tree().create_timer(i * 0.12, false).timeout.connect(explosion.bind(pos + offset, size))


## Искры попадания пули.
func hit(pos: Vector2) -> void:
	spawned.emit(Kind.HIT, pos, 1.0)
	_spawn_pooled(HIT_SPARK, pos, 1.0)


## Вспышка у ствола при выстреле.
func muzzle(pos: Vector2, size := 1.0) -> void:
	_spawn_pooled(MUZZLE_FLASH, pos, size)


## Тряска камеры уровня (если она есть).
func shake(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(strength, duration)


func _find_layer() -> Node:
	var layer := get_tree().get_first_node_in_group(Groups.FX_LAYER)
	if layer == null:
		layer = get_tree().current_scene
	if layer != _layer:
		# Новая сцена — старые пулы ушли вместе с прошлым слоем.
		_layer = layer
		_idle.clear()
		_busy.clear()
	return layer


func _spawn_pooled(scene: PackedScene, pos: Vector2, size: float) -> void:
	var layer := _find_layer()
	if layer == null:
		return
	var busy: int = _busy.get(scene, 0)
	if busy >= int(LIMITS.get(scene, 16)):
		return
	_busy[scene] = busy + 1
	var idle: Array = _idle.get(scene, [])
	while not idle.is_empty():
		var reused = idle.pop_back()
		if is_instance_valid(reused):
			reused.position = pos
			reused.size = size
			reused.play()
			return
	var fx = scene.instantiate()
	fx.position = pos
	fx.size = size
	fx.finished.connect(_release.bind(scene, fx))
	# Эффекты часто создаются из обработчиков коллизий — добавляем отложенно.
	layer.add_child.call_deferred(fx)


func _release(scene: PackedScene, fx: Node) -> void:
	if fx.get_parent() != _layer:
		return
	_busy[scene] = maxi(int(_busy.get(scene, 1)) - 1, 0)
	if not _idle.has(scene):
		_idle[scene] = []
	_idle[scene].append(fx)
