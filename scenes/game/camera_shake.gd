extends Camera2D
## Камера уровня. Стоит в (0, 0) и показывает экран как есть,
## умеет трястись: FX.shake(сила, длительность).

var _strength := 0.0
var _duration := 0.0
var _time_left := 0.0


func shake(strength: float, duration: float) -> void:
	if strength >= _strength * (_time_left / maxf(_duration, 0.001)):
		_strength = strength
		_duration = duration
		_time_left = duration


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		offset = Vector2.ZERO
		return
	_time_left -= delta
	var fade := clampf(_time_left / _duration, 0.0, 1.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength * fade
