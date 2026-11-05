extends Area2D
## Базовый враг: летит по траектории (FlightPattern), может стрелять в игрока.
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
## Урон пули по игроку, HP.
@export var bullet_damage := 20
## Урон тарана, HP.
@export var ram_damage := 25
## Размер взрыва при гибели (1 — обычный).
@export var explosion_size := 1.0

var projectile_container: Node
## Траектория и зеркало. Выставляет уровень до add_child.
var pattern: FlightPattern
var mirrored := false

var _hp := 0
var _dead := false
var _time := 0.0
var _base_x := 0.0
var _fire_cooldown := 0.0
var _alive_time := 0.0
var _was_on_screen := false
var _flash_tween: Tween

var _motion: PatternMotion


func _ready() -> void:
	add_to_group("enemies")
	_hp = max_hp
	_base_x = position.x
	_time = randf() * TAU
	_fire_cooldown = randf_range(0.5, maxf(fire_interval, 0.5))
	area_entered.connect(_on_area_entered)
	if pattern:
		_motion = PatternMotion.new(pattern, mirrored, speed, Arena.rect().size.x)
		position = _motion.position
		rotation = _motion.sprite_rotation()


func _process(delta: float) -> void:
	_time += delta
	_alive_time += delta
	if _motion == null:
		position.y += speed * delta
		if sway_amplitude > 0.0:
			position.x = _base_x + sin(_time * sway_frequency) * sway_amplitude
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		_motion.advance(delta, player.position if player else null)
		position = _motion.position
		rotation = _motion.sprite_rotation()
		if has_node("Sprite"):
			PatternMotion.apply_bank($Sprite, _motion.bank)

	# Удаляем, когда улетел за экран (появляются враги тоже за экраном,
	# поэтому сначала ждём, пока он хоть раз окажется в кадре).
	if Arena.rect().grow(-20.0).has_point(position):
		_was_on_screen = true
	elif (_was_on_screen and not Arena.rect().grow(150.0).has_point(position)) or _alive_time > 30.0:
		queue_free()
		return

	if fire_interval > 0.0 and _can_fire():
		_fire_cooldown -= delta
		if _fire_cooldown <= 0.0:
			_fire_cooldown = fire_interval
			_fire()


func take_damage(amount: int) -> void:
	if _dead:
		return
	_hp -= amount
	modulate = Color(3, 3, 3)
	# Один твин на врага: под плотным огнём новый не плодим, а перезапускаем.
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	if _hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	FX.explosion(global_position, explosion_size)
	destroyed.emit(self)
	queue_free()


## Стреляет только из кадра и только перед игроком: пролетевшие мимо
## и ушедшие за край экрана в спину не бьют.
func _can_fire() -> bool:
	# Только из видимой части мира (не из запаса по бокам за краем экрана).
	if not Arena.visible_rect().grow(-24.0).has_point(position):
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player == null or position.y < player.position.y - 60.0


func _fire() -> void:
	if bullet_scene == null or projectile_container == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var direction := Vector2.DOWN
	if player:
		direction = global_position.direction_to(player.global_position)
	var bullet = Pool.take(bullet_scene)
	bullet.position = global_position
	bullet.velocity = direction * bullet_speed
	bullet.damage = bullet_damage
	projectile_container.add_child(bullet)


func _on_area_entered(area) -> void:
	# Таран: игрок получает урон, враг погибает.
	if area.is_in_group("player") and not _dead:
		area.take_damage(ram_damage)
		_die()
