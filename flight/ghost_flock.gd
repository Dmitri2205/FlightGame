class_name GhostFlock
extends Node2D
## «Призраки» — враги без стрельбы и столкновений, летящие по траекториям
## (PatternMotion). Ими пользуются превью волн и фон главного меню.
## Когда призрак исчезает — решают те же правила Arena, что и для врагов
## в бою (is_air_gone / is_ground_gone), поэтому превью совпадает с боем.

const DEFAULT_TEXTURE := preload("res://art/sprites/enemy_fighter.png")


class Ghost:
	var sprite: Sprite2D
	var motion: PatternMotion
	var ground := false
	var alive_time := 0.0
	var was_on_screen := false
	## Сколько проехала земля под наземным призраком, px.
	var scrolled := 0.0


## Куда доворачивают «охотники» (манёвр AIM).
var target := Vector2.ZERO
var opacity := 0.85

var _ghosts: Array[Ghost] = []


## Выпустить призрака врага из волны (текстура и скорость — как у настоящего врага).
func spawn_for_wave(wave: WaveData, pattern: FlightPattern) -> void:
	var info := EnemyInfo.of(wave.enemy)
	spawn(pattern, info.speed, info.texture, info.is_ground)


func spawn(pattern: FlightPattern, speed: float, texture: Texture2D = null, ground := false) -> void:
	var ghost := Ghost.new()
	ghost.sprite = Sprite2D.new()
	ghost.sprite.texture = texture if texture else DEFAULT_TEXTURE
	ghost.sprite.modulate = Color(1, 1, 1, opacity)
	add_child(ghost.sprite)
	ghost.motion = PatternMotion.new(pattern, speed, Arena.rect().size.x)
	ghost.sprite.position = ghost.motion.position
	ghost.sprite.rotation = ghost.motion.sprite_rotation()
	ghost.ground = ground
	if ground:
		ghost.sprite.z_index = -1
	_ghosts.append(ghost)


## Сдвинуть всех на dt секунд и убрать улетевших за экран.
func advance(dt: float) -> void:
	var alive: Array[Ghost] = []
	for ghost in _ghosts:
		var motion := ghost.motion
		motion.advance(dt, target)
		ghost.alive_time += dt
		var pos := motion.position
		var gone := false
		if ghost.ground:
			# Наземные стоят на земле и уезжают вниз вместе с ней.
			ghost.scrolled += Arena.GROUND_SCROLL_SPEED * dt
			pos.y += ghost.scrolled
			gone = Arena.is_ground_gone(pos, ghost.alive_time)
		else:
			PatternMotion.apply_bank(ghost.sprite, motion.bank)
			if Arena.is_on_screen(pos):
				ghost.was_on_screen = true
			gone = Arena.is_air_gone(pos, ghost.was_on_screen, ghost.alive_time)
		ghost.sprite.position = pos
		if motion.speed > 0.0:
			ghost.sprite.rotation = motion.sprite_rotation()
		if gone:
			ghost.sprite.queue_free()
		else:
			alive.append(ghost)
	_ghosts = alive


func clear() -> void:
	for ghost in _ghosts:
		ghost.sprite.queue_free()
	_ghosts.clear()
