extends Area2D
## Разрушаемый объект на земле (постройки захватчиков: бочки, генераторы,
## антенны). Стоит на земле и уезжает вниз вместе с ней, тарана нет
## (маска коллизий 0), пули попадают (слой врагов). Ракеты его не выбирают
## целью — он не в группе "enemies".
## Даёт немного звёзд, а если на уровне спрятан чертёж — может его уронить
## (бросок делает уровень по сигналу destroyed).

signal destroyed(prop: Node2D)

## Виды: спрайт, прочность, звёзды. Вид выбирается случайно.
const KINDS := [
	{"texture": preload("res://art/sprites/prop_barrel.png"), "hp": 2, "stars": 1},
	{"texture": preload("res://art/sprites/prop_barrel_large.png"), "hp": 4, "stars": 2},
	{"texture": preload("res://art/sprites/prop_generator.png"), "hp": 6, "stars": 3},
	{"texture": preload("res://art/sprites/prop_antenna.png"), "hp": 4, "stars": 2},
]

var score_value := 40
var star_drop := 1

var _hp := 1
var _dead := false
var _scroll_speed := WaveData.GROUND_SCROLL
var _flash_tween: Tween


func _ready() -> void:
	add_to_group("destructibles")
	var kind: Dictionary = KINDS.pick_random()
	$Sprite.texture = kind.texture
	$Sprite.rotation = randi_range(0, 3) * PI / 2.0
	_hp = kind.hp
	star_drop = kind.stars
	score_value = 20 * kind.hp
	var shape := CircleShape2D.new()
	shape.radius = maxf(kind.texture.get_width(), kind.texture.get_height()) * 0.42
	$Collision.shape = shape
	var background := get_tree().get_first_node_in_group("background")
	if background and "scroll_speed" in background:
		_scroll_speed = background.scroll_speed


func _process(delta: float) -> void:
	position.y += _scroll_speed * delta
	if position.y > get_viewport_rect().size.y + 100.0:
		queue_free()


func take_damage(amount: int) -> void:
	if _dead:
		return
	_hp -= amount
	modulate = Color(2.5, 2.5, 2.5)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	if _hp <= 0:
		_dead = true
		FX.explosion(global_position, 0.6, false)
		destroyed.emit(self)
		queue_free()
