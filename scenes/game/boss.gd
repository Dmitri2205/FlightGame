extends Area2D
## Босс: выплывает сверху, ходит из стороны в сторону и чередует атаки.
## На половине здоровья впадает в ярость: быстрее двигается и стреляет плотнее.

signal destroyed(enemy: Node2D)
signal health_changed(current: int, maximum: int)

enum State { ENTERING, FIGHTING }

@export var max_hp := 120
@export var score_value := 5000
@export var star_drop := 40
@export var bullet_scene: PackedScene
@export var bullet_speed := 380.0
@export var entry_y := 260.0
@export var move_speed := 140.0

var projectile_container: Node
var hp := 0

var _state := State.ENTERING
var _dead := false
var _time := 0.0
var _dir := 1.0
var _attack_cooldown := 1.5
var _pattern := 0


func _ready() -> void:
	hp = max_hp
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_time += delta
	match _state:
		State.ENTERING:
			position.y = move_toward(position.y, entry_y, 160.0 * delta)
			if position.y >= entry_y:
				_state = State.FIGHTING
		State.FIGHTING:
			_move(delta)
			_attack_cooldown -= delta
			if _attack_cooldown <= 0.0:
				_attack()


func is_enraged() -> bool:
	return hp * 2 <= max_hp


func take_damage(amount: int) -> void:
	# Пока выплывает — неуязвим, чтобы не сбить его ещё за экраном.
	if _dead or _state == State.ENTERING:
		return
	var was_enraged := is_enraged()
	hp = maxi(hp - amount, 0)
	health_changed.emit(hp, max_hp)
	modulate = Color(2, 2, 2)
	create_tween().tween_property(self, "modulate", _base_modulate(), 0.08)
	if hp == 0:
		_dead = true
		destroyed.emit(self)
		queue_free()
	elif is_enraged() and not was_enraged:
		_attack_cooldown = 0.6


func _move(delta: float) -> void:
	var width := get_viewport_rect().size.x
	var speed := move_speed * (1.6 if is_enraged() else 1.0)
	position.x += _dir * speed * delta
	if position.x < 130.0:
		_dir = 1.0
	elif position.x > width - 130.0:
		_dir = -1.0
	position.y = entry_y + sin(_time * 1.3) * 30.0


func _attack() -> void:
	if is_enraged():
		match _pattern % 3:
			0:
				_ring(18, 0.0)
			1:
				_fan(Vector2(0, 60), 7, 0.9)
			2:
				_ring(18, PI / 18.0)
				_fan(Vector2(0, 60), 3, 0.3)
		_attack_cooldown = 0.9
	else:
		match _pattern % 2:
			0:
				_fan(Vector2(0, 60), 5, 0.6)
			1:
				_shoot(Vector2(-90, 40), Vector2.DOWN)
				_shoot(Vector2(90, 40), Vector2.DOWN)
				_shoot(Vector2(-90, 40), Vector2.DOWN.rotated(0.15))
				_shoot(Vector2(90, 40), Vector2.DOWN.rotated(-0.15))
		_attack_cooldown = 1.4
	_pattern += 1


## Веер пуль в сторону игрока.
func _fan(offset: Vector2, count: int, spread: float) -> void:
	var origin := global_position + offset
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var aim := Vector2.DOWN
	if player:
		aim = origin.direction_to(player.global_position)
	for i in count:
		var t := 0.0 if count == 1 else float(i) / (count - 1) - 0.5
		_shoot(offset, aim.rotated(t * spread))


## Кольцо пуль во все стороны.
func _ring(count: int, angle_offset: float) -> void:
	for i in count:
		_shoot(Vector2.ZERO, Vector2.DOWN.rotated(angle_offset + TAU * i / count))


func _shoot(offset: Vector2, direction: Vector2) -> void:
	if bullet_scene == null or projectile_container == null:
		return
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position + offset
	bullet.velocity = direction * bullet_speed
	projectile_container.add_child(bullet)


func _base_modulate() -> Color:
	return Color(1.25, 0.8, 0.8) if is_enraged() else Color.WHITE


func _on_area_entered(area) -> void:
	# Таран босса бьёт игрока, но сам босс не погибает.
	if area.is_in_group("player"):
		area.take_damage(1)
