extends Node2D
## Одноразовый эффект: запускает все частицы-потомки и вспышку (узел Flash),
## через `duration` секунд прячется и шлёт finished. Дальше решает FX:
## частые эффекты (вспышки выстрелов, искры) возвращаются в пул и
## переиспользуются, редкие (взрывы) удаляются.
## Анимация — в _process, без твинов и таймеров: их создание на каждый
## выстрел заметно грузило кадр.

signal finished

@export var duration := 1.5
## До какого масштаба раздувается вспышка.
@export var flash_scale := 3.0

var size := 1.0

var _age := 0.0
var _flash: Sprite2D
var _flash_alpha := 1.0
var _particles: Array[CPUParticles2D] = []


func _ready() -> void:
	_flash = get_node_or_null("Flash") as Sprite2D
	if _flash:
		_flash_alpha = _flash.modulate.a
	for child in get_children():
		if child is CPUParticles2D:
			_particles.append(child)
	play()


## Запуск (и повторный запуск из пула).
func play() -> void:
	scale = Vector2.ONE * size
	_age = 0.0
	show()
	set_process(true)
	for particles in _particles:
		particles.restart()
	_animate_flash()


func _process(delta: float) -> void:
	_age += delta
	_animate_flash()
	if _age >= duration:
		set_process(false)
		hide()
		finished.emit()


func _animate_flash() -> void:
	if _flash == null:
		return
	_flash.scale = Vector2.ONE * lerpf(0.5, flash_scale, minf(_age / 0.18, 1.0))
	_flash.modulate.a = _flash_alpha * maxf(0.0, 1.0 - _age / 0.25)
