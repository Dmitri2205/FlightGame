extends Area2D
## Корабль игрока: движется за пальцем, стреляет автоматически.

signal health_changed(current: int, maximum: int)
signal died

@export var bullet_scene: PackedScene
@export var bullet_speed := 1400.0
@export var keyboard_speed := 600.0
@export var invulnerability_time := 1.0

## Куда складывать пули (выставляет уровень).
var projectile_container: Node

var max_health := 3
var health := 3
var magnet_radius := 60.0

var _fire_interval := 0.25
var _fire_cooldown := 0.0
var _main_damage := 1
var _wing_level := 0
var _wing_damage := 1
var _invulnerable_left := 0.0


func _ready() -> void:
	add_to_group("player")
	max_health = GameState.player_max_health()
	health = max_health
	magnet_radius = GameState.magnet_radius()
	_fire_interval = GameState.fire_interval()
	_main_damage = GameState.main_cannon_damage()
	_wing_level = GameState.wing_cannons_level()
	_wing_damage = GameState.wing_cannon_damage()


func _unhandled_input(event: InputEvent) -> void:
	# Мышь эмулирует тач (см. project.godot), поэтому одного обработчика достаточно.
	if event is InputEventScreenDrag:
		position += event.relative
		_clamp_to_screen()


func _process(delta: float) -> void:
	# Клавиатура — для отладки на ПК.
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		position += dir * keyboard_speed * delta
		_clamp_to_screen()

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = _fire_interval
		_fire()

	if _invulnerable_left > 0.0:
		_invulnerable_left -= delta
		visible = _invulnerable_left <= 0.0 or int(_invulnerable_left * 15.0) % 2 == 0


func take_damage(amount: int) -> void:
	if _invulnerable_left > 0.0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		died.emit()
		queue_free()
	else:
		_invulnerable_left = invulnerability_time


func _fire() -> void:
	_spawn_bullet(Vector2(0, -44), Vector2.UP, _main_damage)
	if _wing_level > 0:
		var spread := 0.04 + 0.01 * _wing_level
		_spawn_bullet(Vector2(-26, -8), Vector2.UP.rotated(-spread), _wing_damage)
		_spawn_bullet(Vector2(26, -8), Vector2.UP.rotated(spread), _wing_damage)


func _spawn_bullet(offset: Vector2, direction: Vector2, damage: int) -> void:
	if bullet_scene == null or projectile_container == null:
		return
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position + offset
	bullet.velocity = direction * bullet_speed
	bullet.damage = damage
	projectile_container.add_child(bullet)


func _clamp_to_screen() -> void:
	var rect := get_viewport_rect()
	position.x = clampf(position.x, 30.0, rect.size.x - 30.0)
	position.y = clampf(position.y, 60.0, rect.size.y - 40.0)
