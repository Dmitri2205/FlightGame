extends Area2D
## Звезда-валюта. Разлетается из сбитого врага, падает вниз,
## в радиусе магнита притягивается к игроку (см. PickupMotion).

signal collected


func _ready() -> void:
	$Motion.collected.connect(collected.emit)
