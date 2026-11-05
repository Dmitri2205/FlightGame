extends Area2D
## Выпавший чертёж. Подпрыгивает, мерцает и через мгновение сам летит
## к игроку (чтобы не потерять редкую находку за краем экрана).
## Засчитывается, только если долететь до конца уровня.

signal collected

const HOME_DELAY := 0.7
const HOME_SPEED := 700.0

var velocity := Vector2.ZERO
var _age := 0.0


func _ready() -> void:
	velocity = Vector2(randf_range(-80.0, 80.0), -220.0)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_age += delta
	var player = get_tree().get_first_node_in_group("player")
	if _age > HOME_DELAY and player:
		velocity = position.direction_to(player.position) * HOME_SPEED
	else:
		velocity = velocity.move_toward(Vector2(0, 120), 400.0 * delta)
	position += velocity * delta
	$Glow.scale = Vector2.ONE * (1.6 + 0.3 * sin(_age * 8.0))
	if position.y > get_viewport_rect().size.y + 60.0:
		queue_free()


func _on_area_entered(area) -> void:
	if area.is_in_group("player"):
		collected.emit()
		queue_free()
