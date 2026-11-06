class_name Destructible
extends EnemyBase
## Разрушаемый объект на земле (постройки захватчиков: бочки, генераторы,
## антенны). Стоит на земле и уезжает вниз вместе с ней, тарана нет
## (маска коллизий 0), пули попадают (слой врагов). Ракеты его не выбирают
## целью — он не в группе "enemies".
## Даёт немного звёзд, а если на уровне спрятан чертёж — может его уронить
## (бросок делает уровень по сигналу destroyed).
## Вид (спрайт, прочность, награда, взрыв, 3D-модель) — случайный PropKind
## из списка мелких или крупных.

## Что остаётся на месте разрушенной постройки: тёмная воронка.
const SCORCH := preload("res://art/sprites/decor_crater.png")
const SCORCH_TINT := Color(0.18, 0.13, 0.12, 0.85)
## Воронка чуть меньше постройки (доля её размера).
const SCORCH_SCALE := 0.9
## Радиус попадания — доля большей стороны спрайта.
const HIT_RADIUS_SHARE := 0.42
## Крупная постройка рушится серией взрывов: сколько, в каком радиусе, какого размера.
const LARGE_CHAIN_COUNT := 3
const LARGE_CHAIN_RADIUS := 40.0
const LARGE_CHAIN_SIZE := 0.8
## Ушла ниже нижнего края мира на столько px — удаляется.
const DESPAWN_MARGIN := 100.0

## Мелкие — бочки, генераторы, антенны; крупные — ангары, тарелки связи
## (центр «базы»).
@export var small_kinds: Array[PropKind] = []
@export var large_kinds: Array[PropKind] = []

## Крупная постройка (выбирает уровень до add_child).
var large := false
## Размер спрайта (большая сторона), px — для 3D-вида.
var sprite_size := 0.0


func _ready() -> void:
	add_to_group("destructibles")
	var kind: PropKind = (large_kinds if large else small_kinds).pick_random()
	$Sprite.texture = kind.texture
	$Sprite.rotation = randi_range(0, 3) * PI / 2.0
	model_3d = kind.model_3d
	sprite_size = maxf(kind.texture.get_width(), kind.texture.get_height())
	hp = kind.hp
	explosion_size = kind.blast
	star_drop = kind.stars
	score_value = kind.score_value()
	var shape := CircleShape2D.new()
	shape.radius = sprite_size * HIT_RADIUS_SHARE
	$Collision.shape = shape


func _process(delta: float) -> void:
	position.y += Arena.GROUND_SCROLL_SPEED * delta
	if position.y > Arena.rect().size.y + DESPAWN_MARGIN:
		queue_free()


## Взрыв, а на месте постройки — воронка, которая уезжает вместе с землёй.
func _die() -> void:
	_dead = true
	FX.explosion(global_position, explosion_size, large)
	if large:
		FX.chain_explosions(global_position, LARGE_CHAIN_COUNT, LARGE_CHAIN_RADIUS, LARGE_CHAIN_SIZE)
	destroyed.emit(self)
	$Collision.set_deferred("disabled", true)
	$Shadow.hide()
	$Sprite.texture = SCORCH
	$Sprite.scale = Vector2.ONE * (sprite_size / SCORCH.get_width()) * SCORCH_SCALE
	$Sprite.self_modulate = SCORCH_TINT
	z_index = -6
