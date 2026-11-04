extends Area2D
## Базовый враг: летит по траектории (см. FlightPatterns), может стрелять в игрока.
## Без траектории просто летит вниз и при желании виляет (sway_*).
## Разные типы врагов — это разные сцены с другими параметрами.

signal destroyed(enemy: Node2D)

@export var max_hp := 2
@export var speed := 220.0
@export var score_value := 100
@export var star_drop := 2
@export var sway_amplitude := 0.0
@export var sway_frequency := 2.0
## 0 — враг не стреляет.
@export var fire_interval := 0.0
@export var bullet_scene: PackedScene
@export var bullet_speed := 450.0

var projectile_container: Node
## Траектория из FlightPatterns.get_pattern(). Выставляет уровень до add_child.
var pattern: Dictionary = {}
var mirrored := false

var _hp := 0
var _dead := false
var _time := 0.0
var _base_x := 0.0
var _fire_cooldown := 0.0
var _alive_time := 0.0
var _was_on_screen := false

var _heading := Vector2.DOWN
var _steps: Array = []
var _step_index := 0
## Пройденная часть текущего манёвра: пиксели, радианы или секунды.
var _step_progress := 0.0
var _speed_scale := 1.0


func _ready() -> void:
	_hp = max_hp
	_base_x = position.x
	_time = randf() * TAU
	_fire_cooldown = randf_range(0.5, maxf(fire_interval, 0.5))
	area_entered.connect(_on_area_entered)
	if not pattern.is_empty():
		_heading = FlightPatterns.heading_vector(pattern.heading, mirrored)
		_steps = pattern.steps
		rotation = _heading.angle() - PI / 2.0


func _process(delta: float) -> void:
	_time += delta
	_alive_time += delta
	if pattern.is_empty():
		position.y += speed * delta
		if sway_amplitude > 0.0:
			position.x = _base_x + sin(_time * sway_frequency) * sway_amplitude
	else:
		_fly(delta)

	# Удаляем, когда улетел за экран (появляются враги тоже за экраном,
	# поэтому сначала ждём, пока он хоть раз окажется в кадре).
	if get_viewport_rect().grow(-20.0).has_point(position):
		_was_on_screen = true
	elif (_was_on_screen and not get_viewport_rect().grow(150.0).has_point(position)) or _alive_time > 30.0:
		queue_free()
		return

	if fire_interval > 0.0 and position.y > 0.0:
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown = fire_interval
			_fire()


func _fly(delta: float) -> void:
	var step: Dictionary = _steps[_step_index] if _step_index < _steps.size() else {}
	var target_scale := 1.0
	match step.get("type", -1):
		FlightPatterns.Step.LINE:
			_step_progress += speed * delta
			if _step_progress >= step.length:
				_next_step()
		FlightPatterns.Step.TURN:
			var total: float = -step.angle if mirrored else step.angle
			var turn_step := minf(speed / step.radius * delta, absf(total) - _step_progress)
			# Против часовой на экране (ось y вниз) = отрицательный поворот вектора.
			_heading = _heading.rotated(-signf(total) * turn_step)
			_step_progress += turn_step
			if _step_progress >= absf(total) - 0.0001:
				_next_step()
		FlightPatterns.Step.AIM:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player:
				var angle := _heading.angle_to(position.direction_to(player.position))
				var max_turn: float = step.turn_rate * delta
				_heading = _heading.rotated(clampf(angle, -max_turn, max_turn))
			_step_progress += delta
			if _step_progress >= step.duration:
				_next_step()
		FlightPatterns.Step.HOVER:
			target_scale = 0.08
			_step_progress += delta
			if _step_progress >= step.duration:
				_next_step()

	# Плавно тормозим/разгоняемся при зависании.
	_speed_scale = move_toward(_speed_scale, target_scale, 3.0 * delta)
	position += _heading * speed * _speed_scale * delta
	rotation = _heading.angle() - PI / 2.0


func _next_step() -> void:
	_step_index += 1
	_step_progress = 0.0


func take_damage(amount: int) -> void:
	if _dead:
		return
	_hp -= amount
	modulate = Color(3, 3, 3)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.1)
	if _hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	destroyed.emit(self)
	queue_free()


func _fire() -> void:
	if bullet_scene == null or projectile_container == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var direction := Vector2.DOWN
	if player:
		direction = global_position.direction_to(player.global_position)
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position
	bullet.velocity = direction * bullet_speed
	projectile_container.add_child(bullet)


func _on_area_entered(area) -> void:
	# Таран: игрок получает урон, враг погибает.
	if area.is_in_group("player") and not _dead:
		area.take_damage(1)
		_die()
