class_name FlightPattern
extends Resource
## Траектория врага: точка появления, начальный курс и цепочка манёвров.
## После последнего манёвра враг летит прямо, пока не уйдёт с экрана.
## Зеркальную копию даёт mirrored() — единственное место, где траектория отражается.
## Библиотека — flight/patterns/*.tres, посмотреть путь — экран «Превью волн».

@export var title := ""
## x — доля ширины экрана (0..1, можно чуть за краем),
## y — пиксели от верха (отрицательные — выше экрана).
@export var start := Vector2(0.5, -60)
## Начальный курс, градусы: 0 — вниз, 90 — вправо, -90 — влево, 180 — вверх.
@export var heading := 0.0
## Манёвры (FlightStep) по порядку.
@export var steps: Array = []


## Точка появления в пикселях.
func start_position(screen_width: float) -> Vector2:
	return Vector2(start.x * screen_width, start.y)


## Начальный курс → вектор направления.
func heading_vector() -> Vector2:
	var a := deg_to_rad(heading)
	return Vector2(sin(a), cos(a))


## Копия, отражённая по горизонтали относительно центра экрана:
## точка появления, курс и все повороты зеркальны. Исходник не меняется.
func mirrored() -> FlightPattern:
	var copy: FlightPattern = duplicate()
	copy.start.x = 1.0 - start.x
	copy.heading = -heading
	copy.steps = steps.map(func(step: FlightStep) -> FlightStep: return step.mirrored())
	return copy
