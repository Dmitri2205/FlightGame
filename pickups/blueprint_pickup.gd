extends Area2D
## Выпавший чертёж. Подпрыгивает, мерцает и через мгновение сам летит
## к игроку (чтобы не потерять редкую находку за краем экрана).
## Засчитывается, только если долететь до конца уровня.

signal collected

@onready var _motion: PickupMotion = $Motion
@onready var _glow: Sprite2D = $Glow


func _ready() -> void:
	_motion.collected.connect(collected.emit)


func _process(_delta: float) -> void:
	_glow.scale = Vector2.ONE * (1.6 + 0.3 * sin(_motion.age * 8.0))
