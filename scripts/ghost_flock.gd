class_name GhostFlock
extends Node2D
## «Призраки» — враги без стрельбы и столкновений, летящие по траекториям
## (PatternMotion). Ими пользуются превью волн и фон главного меню.

const DEFAULT_TEXTURE := preload("res://art/sprites/enemy_fighter.png")

## Куда доворачивают «охотники» (манёвр AIM).
var target := Vector2.ZERO
var opacity := 0.85

## Скорость прокрутки земли для наземных призраков (танки, турели), px/с.
var ground_scroll := WaveData.GROUND_SCROLL

## [{sprite, motion, time, seen, ground, scrolled}]
var _ghosts: Array[Dictionary] = []
## Кэш по сцене врага: {texture, speed}
var _enemy_info := {}


## Выпустить призрака врага из волны (текстура и скорость — как у настоящего врага).
func spawn_for_wave(wave: WaveData, pattern: FlightPattern, mirrored: bool) -> void:
	var info := enemy_info(wave.enemy)
	spawn(pattern, mirrored, info.speed, info.texture, info.ground)


func spawn(pattern: FlightPattern, mirrored: bool, speed: float, texture: Texture2D = null, ground := false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture if texture else DEFAULT_TEXTURE
	sprite.modulate = Color(1, 1, 1, opacity)
	add_child(sprite)
	var motion := PatternMotion.new(pattern, mirrored, speed, Arena.rect().size.x)
	sprite.position = motion.position
	sprite.rotation = motion.sprite_rotation()
	if ground:
		sprite.z_index = -1
	_ghosts.append({"sprite": sprite, "motion": motion, "time": 0.0, "seen": false, "ground": ground, "scrolled": 0.0})


## Сдвинуть всех на dt секунд и убрать улетевших за экран.
func advance(dt: float) -> void:
	var screen := Arena.rect()
	var alive: Array[Dictionary] = []
	for ghost in _ghosts:
		var motion: PatternMotion = ghost.motion
		motion.advance(dt, target)
		ghost.time += dt
		var pos := motion.position
		if ghost.ground:
			# Наземные стоят на земле и уезжают вниз вместе с ней.
			ghost.scrolled += ground_scroll * dt
			pos.y += ghost.scrolled
		else:
			PatternMotion.apply_bank(ghost.sprite, motion.bank)
		ghost.sprite.position = pos
		if motion.speed > 0.0:
			ghost.sprite.rotation = motion.sprite_rotation()
		if screen.has_point(pos):
			ghost.seen = true
		var gone: bool = (ghost.seen and not screen.grow(150.0).has_point(pos)) or ghost.time > 60.0
		if gone:
			ghost.sprite.queue_free()
		else:
			alive.append(ghost)
	_ghosts = alive


func clear() -> void:
	for ghost in _ghosts:
		ghost.sprite.queue_free()
	_ghosts.clear()


## Текстура и скорость врага по его сцене (с кэшем).
func enemy_info(scene: PackedScene) -> Dictionary:
	if not _enemy_info.has(scene):
		var enemy = scene.instantiate()
		var sprite := enemy.get_node_or_null("Sprite") as Sprite2D
		_enemy_info[scene] = {"texture": sprite.texture if sprite else null, "speed": float(enemy.speed), "ground": "is_ground" in enemy}
		enemy.free()
	return _enemy_info[scene]
