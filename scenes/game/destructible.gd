extends Area2D
## Разрушаемый объект на земле (постройки захватчиков: бочки, генераторы,
## антенны). Стоит на земле и уезжает вниз вместе с ней, тарана нет
## (маска коллизий 0), пули попадают (слой врагов). Ракеты его не выбирают
## целью — он не в группе "enemies".
## Даёт немного звёзд, а если на уровне спрятан чертёж — может его уронить
## (бросок делает уровень по сигналу destroyed).

signal destroyed(prop: Node2D)

## Виды: спрайт, прочность, звёзды, размер взрыва. Мелкие — бочки, генераторы,
## антенны; крупные — ангары, тарелки связи (центр «базы»).
const SMALL := [
	{"texture": preload("res://art/sprites/prop_barrel.png"), "model": "machine_barrel", "hp": 2, "stars": 1, "blast": 0.6},
	{"texture": preload("res://art/sprites/prop_barrel_large.png"), "model": "machine_barrelLarge", "hp": 4, "stars": 2, "blast": 0.7},
	{"texture": preload("res://art/sprites/prop_generator.png"), "model": "machine_generator", "hp": 6, "stars": 3, "blast": 0.8},
	{"texture": preload("res://art/sprites/prop_antenna.png"), "model": "machine_wireless", "hp": 4, "stars": 2, "blast": 0.7},
]
const LARGE := [
	{"texture": preload("res://art/sprites/prop_hangar_large.png"), "model": "hangar_largeA", "hp": 30, "stars": 10, "blast": 1.6},
	{"texture": preload("res://art/sprites/prop_hangar_round.png"), "model": "hangar_roundA", "hp": 24, "stars": 8, "blast": 1.5},
	{"texture": preload("res://art/sprites/prop_hangar_small.png"), "model": "hangar_smallA", "hp": 18, "stars": 6, "blast": 1.3},
	{"texture": preload("res://art/sprites/prop_dish.png"), "model": "satelliteDish_large", "hp": 16, "stars": 6, "blast": 1.3},
	{"texture": preload("res://art/sprites/prop_generator_large.png"), "model": "machine_generatorLarge", "hp": 14, "stars": 5, "blast": 1.2},
]
## Что остаётся на месте разрушенной постройки: тёмная воронка.
const SCORCH := preload("res://art/sprites/decor_crater.png")

## Крупная постройка (выбирает уровень до add_child).
var large := false
## Модель пака для 3D-вида и размер спрайта (px).
var model_name := ""
var sprite_size := 64.0
var score_value := 40
var star_drop := 1

var _hp := 1
var _blast := 0.6
var _dead := false
var _scroll_speed := WaveData.GROUND_SCROLL
var _flash_tween: Tween


func _ready() -> void:
	add_to_group("destructibles")
	var kind: Dictionary = (LARGE if large else SMALL).pick_random()
	$Sprite.texture = kind.texture
	$Sprite.rotation = randi_range(0, 3) * PI / 2.0
	model_name = kind.model
	sprite_size = maxf(kind.texture.get_width(), kind.texture.get_height())
	_hp = kind.hp
	_blast = kind.blast
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
	if position.y > Arena.rect().size.y + 100.0:
		queue_free()


func is_destroyed() -> bool:
	return _dead


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
		_destroy()


## Взрыв, а на месте постройки — воронка, которая уезжает вместе с землёй.
func _destroy() -> void:
	_dead = true
	FX.explosion(global_position, _blast, large)
	if large:
		FX.chain_explosions(global_position, 3, 40.0, 0.8)
	destroyed.emit(self)
	$Collision.set_deferred("disabled", true)
	$Shadow.hide()
	var size: float = maxf($Sprite.texture.get_width(), $Sprite.texture.get_height())
	$Sprite.texture = SCORCH
	$Sprite.scale = Vector2.ONE * (size / SCORCH.get_width()) * 0.9
	$Sprite.self_modulate = Color(0.18, 0.13, 0.12, 0.85)
	z_index = -6
