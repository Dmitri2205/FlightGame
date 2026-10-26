extends Area2D
## Базовый враг: летит вниз, может вилять и стрелять в игрока.
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

var _hp := 0
var _dead := false
var _time := 0.0
var _base_x := 0.0
var _fire_cooldown := 0.0


func _ready() -> void:
	_hp = max_hp
	_base_x = position.x
	_time = randf() * TAU
	_fire_cooldown = randf_range(0.5, maxf(fire_interval, 0.5))
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_time += delta
	position.y += speed * delta
	if sway_amplitude > 0.0:
		position.x = _base_x + sin(_time * sway_frequency) * sway_amplitude

	if position.y > get_viewport_rect().size.y + 80.0:
		queue_free()
		return

	if fire_interval > 0.0 and position.y > 0.0:
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown = fire_interval
			_fire()


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
