class_name PatternMotion
extends RefCounted
## Движение по траектории — общий расчёт для врага в игре и для превью,
## поэтому превью показывает ровно тот путь, что будет в бою.

var pattern: FlightPattern
var mirrored := false
var speed := 220.0
var position := Vector2.ZERO
var heading := Vector2.DOWN
## Крен −1..1: насколько корабль завален на бок на вираже (знак — сторона).
var bank := 0.0

## Угловая скорость поворота (рад/с), при которой крен максимальный.
const FULL_BANK_TURN_RATE := 2.2
## Как быстро корабль входит в крен и выходит из него (в долях за секунду).
const BANK_RESPONSE := 4.0

var _step_index := 0
## Пройденная часть текущего манёвра: пиксели, радианы или секунды.
var _step_progress := 0.0
var _speed_scale := 1.0


func _init(p_pattern: FlightPattern, p_mirrored: bool, p_speed: float, screen_width: float) -> void:
	pattern = p_pattern
	mirrored = p_mirrored
	speed = p_speed
	position = pattern.start_position(screen_width, mirrored)
	heading = pattern.heading_vector(mirrored)


## Угол поворота спрайта (спрайты врагов нарисованы носом вниз).
func sprite_rotation() -> float:
	return heading.angle() - PI / 2.0


## Сдвинуть на delta секунд. target — куда доворачивать в манёвре AIM (обычно игрок).
func advance(delta: float, target = null) -> void:
	var previous_heading := heading
	var step: FlightStep = pattern.steps[_step_index] if _step_index < pattern.steps.size() else null
	var target_scale := 1.0
	if step:
		match step.type:
			FlightStep.Type.LINE:
				_step_progress += speed * delta
				if _step_progress >= step.distance:
					_next_step()
			FlightStep.Type.TURN:
				var total := deg_to_rad(-step.angle if mirrored else step.angle)
				var turn_step := minf(speed / step.radius * delta, absf(total) - _step_progress)
				# Против часовой на экране (ось y вниз) = отрицательный поворот вектора.
				heading = heading.rotated(-signf(total) * turn_step)
				_step_progress += turn_step
				if _step_progress >= absf(total) - 0.0001:
					_next_step()
			FlightStep.Type.AIM:
				if target is Vector2:
					var angle := heading.angle_to(position.direction_to(target))
					var max_turn := deg_to_rad(step.turn_rate) * delta
					heading = heading.rotated(clampf(angle, -max_turn, max_turn))
				_step_progress += delta
				if _step_progress >= step.duration:
					_next_step()
			FlightStep.Type.HOVER:
				target_scale = 0.08
				_step_progress += delta
				if _step_progress >= step.duration:
					_next_step()

	# Плавно тормозим/разгоняемся при зависании.
	_speed_scale = move_toward(_speed_scale, target_scale, 3.0 * delta)
	position += heading * speed * _speed_scale * delta

	# Крен — от того, как быстро сейчас поворачиваем.
	if delta > 0.0:
		var turn_rate := previous_heading.angle_to(heading) / delta
		var target_bank := clampf(turn_rate / FULL_BANK_TURN_RATE, -1.0, 1.0)
		bank = move_toward(bank, target_bank, BANK_RESPONSE * delta)


## Применить крен к спрайту: силуэт сужается и перекашивается, будто корабль
## завалился на бок. base_scale — обычный масштаб спрайта.
static func apply_bank(sprite: Node2D, bank_value: float, base_scale := Vector2.ONE) -> void:
	sprite.scale = Vector2(base_scale.x * (1.0 - 0.45 * absf(bank_value)), base_scale.y)
	# Знак минус: при повороте вправо корабль заваливается на правое крыло.
	sprite.skew = -bank_value * 0.35


func _next_step() -> void:
	_step_index += 1
	_step_progress = 0.0
