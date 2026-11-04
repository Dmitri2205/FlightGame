class_name FlightPatterns
extends RefCounted
## Библиотека траекторий врагов.
##
## Траектория = точка появления + начальный курс + цепочка манёвров.
## Враг выполняет манёвры по очереди, а после последнего летит прямо,
## пока не покинет экран.
##
## Координаты появления: x — доля ширины экрана (0..1, можно чуть за краем),
## y — пиксели от верха (отрицательные — выше экрана).
## Курс в градусах: 0 — вниз, 90 — вправо, -90 — влево, 180 — вверх.
## Поворот: положительный угол — против часовой стрелки на экране
## (летящий вниз враг уходит к правому краю), отрицательный — по часовой.
##
## Зеркальная траектория (mirrored) отражает всё по горизонтали.

enum Step { LINE, TURN, AIM, HOVER }


## Лететь прямо `length` пикселей.
static func line(length: float) -> Dictionary:
	return {"type": Step.LINE, "length": length}


## Повернуть на `degrees` по дуге радиуса `radius` px (360 — мёртвая петля).
static func turn(degrees: float, radius: float) -> Dictionary:
	return {"type": Step.TURN, "angle": deg_to_rad(degrees), "radius": radius}


## Доворачивать на игрока `duration` секунд со скоростью `turn_rate` град/с.
static func aim(duration: float, turn_rate := 240.0) -> Dictionary:
	return {"type": Step.AIM, "duration": duration, "turn_rate": deg_to_rad(turn_rate)}


## Почти остановиться на `duration` секунд (например, чтобы постоять и пострелять).
static func hover(duration: float) -> Dictionary:
	return {"type": Step.HOVER, "duration": duration}


static func ids() -> Array[String]:
	return ["dive", "diagonal", "loop", "swoop", "side_sweep", "zigzag", "s_curve", "hunter", "drift"]


static func get_pattern(id: String) -> Dictionary:
	match id:
		"dive":  # прямо вниз
			return _make(Vector2(0.5, -60), 0, [])
		"diagonal":  # наискось через весь экран
			return _make(Vector2(0.05, -60), 30, [])
		"loop":  # пикирует, крутит мёртвую петлю и летит дальше
			return _make(Vector2(0.3, -60), 0, [line(480), turn(360, 110)])
		"swoop":  # ныряет вниз и разворачивается обратно вверх
			return _make(Vector2(0.15, -60), 15, [line(420), turn(180, 150)])
		"side_sweep":  # влетает сбоку и заворачивает вниз
			return _make(Vector2(-0.05, 260), 90, [line(160), turn(-90, 200)])
		"zigzag":  # змейка
			return _make(Vector2(0.2, -60), 35, [
				line(260), turn(-70, 60),
				line(260), turn(70, 60),
				line(260), turn(-70, 60),
			])
		"s_curve":  # S-образный заход
			return _make(Vector2(0.4, -60), 0, [turn(90, 130), turn(-180, 130), turn(90, 130)])
		"hunter":  # влетает, замирает и бросается на игрока
			return _make(Vector2(0.5, -60), 0, [line(260), hover(0.6), aim(0.5, 360)])
		"drift":  # тяжёлый: заходит, висит и стреляет, потом уходит
			return _make(Vector2(0.5, -80), 0, [line(320), hover(3.5)])
	push_error("Неизвестная траектория: %s" % id)
	return _make(Vector2(0.5, -60), 0, [])


## Курс в градусах → вектор направления (с учётом зеркала).
static func heading_vector(degrees: float, mirrored: bool) -> Vector2:
	var a := deg_to_rad(-degrees if mirrored else degrees)
	return Vector2(sin(a), cos(a))


## Точка появления в пикселях (с учётом зеркала).
static func start_position(pattern: Dictionary, screen_width: float, mirrored: bool) -> Vector2:
	var start: Vector2 = pattern.start
	var x := (1.0 - start.x) if mirrored else start.x
	return Vector2(x * screen_width, start.y)


static func _make(start: Vector2, heading: float, steps: Array) -> Dictionary:
	return {"start": start, "heading": heading, "steps": steps}
