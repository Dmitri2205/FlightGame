class_name FlightPattern
extends Resource
## Траектория врага: точка появления, начальный курс и цепочка манёвров.
## После последнего манёвра враг летит прямо, пока не уйдёт с экрана.
## Зеркальная траектория (mirrored) отражает всё по горизонтали.
## Библиотека — data/patterns/*.tres, посмотреть путь — экран «Превью волн».

@export var title := ""
## x — доля ширины экрана (0..1, можно чуть за краем),
## y — пиксели от верха (отрицательные — выше экрана).
@export var start := Vector2(0.5, -60)
## Начальный курс, градусы: 0 — вниз, 90 — вправо, -90 — влево, 180 — вверх.
@export var heading := 0.0
## Манёвры (FlightStep) по порядку.
@export var steps: Array = []


## Точка появления в пикселях (с учётом зеркала).
func start_position(screen_width: float, mirrored: bool) -> Vector2:
	var x := (1.0 - start.x) if mirrored else start.x
	return Vector2(x * screen_width, start.y)


## Начальный курс → вектор направления (с учётом зеркала).
func heading_vector(mirrored: bool) -> Vector2:
	var a := deg_to_rad(-heading if mirrored else heading)
	return Vector2(sin(a), cos(a))
