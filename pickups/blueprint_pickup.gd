extends Area2D
## Выпавший чертёж. Парит там, где выпал, покачивается и мерцает.
## Магнит его не тянет — игрок должен долететь до него сам.
## Засчитывается, только если долететь до конца уровня.

signal collected

const BOB_HEIGHT := 6.0
const BOB_SPEED := 3.0

@onready var _motion: PickupMotion = $Motion
@onready var _glow: Sprite2D = $Glow
@onready var _icon: Sprite2D = $Icon


func _ready() -> void:
	_motion.collected.connect(collected.emit)


func _process(_delta: float) -> void:
	_glow.scale = Vector2.ONE * (1.6 + 0.3 * sin(_motion.age * 8.0))
	# Покачивание — только картинка, хитбокс стоит на месте.
	var bob := Vector2(0.0, BOB_HEIGHT * sin(_motion.age * BOB_SPEED))
	_icon.position = bob
	_glow.position = bob
