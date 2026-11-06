extends Node
## Размер игрового мира в его собственных координатах. Подключено как
## autoload `Arena`.
##
## Камера уровня отдалена (Camera2D.zoom < 1): мир больше экрана, объекты на
## экране мельче, поле боя «шире». Поэтому всё игровое (границы, точки
## появления, выход за край) считается от Arena.rect(), а не от
## get_viewport_rect(). Камера стоит в (0, 0) с якорем в левом верхнем углу.
## Без камеры (меню, превью) мир совпадает с экраном.
##
## Здесь же — общие правила мира, одинаковые для боя и превью волн:
## скорость земли, где появляется игрок, когда враг считается улетевшим.

## Скорость прокрутки земли в бою, px/с. Единственный источник: фон уровня,
## наземные враги, постройки, призраки превью, 3D-вид и расчёт волн
## (WaveData.spawn_interval) берут её отсюда.
const GROUND_SCROLL_SPEED := 120.0

## Игрок появляется по центру, на столько px выше нижнего края мира.
const PLAYER_SPAWN_FROM_BOTTOM := 200.0

## Враг «побывал в кадре», когда зашёл внутрь мира хотя бы на столько px.
const ON_SCREEN_INSET := 20.0
## Побывавший в кадре самолёт удаляется, когда улетел за край дальше этого, px.
const DESPAWN_MARGIN := 150.0
## Наземный удаляется, когда уехал с землёй ниже нижнего края на столько px.
const GROUND_DESPAWN_MARGIN := 120.0
## Предельное время жизни врага, с (на случай траектории, не уходящей с экрана).
const AIR_MAX_LIFETIME := 30.0
const GROUND_MAX_LIFETIME := 60.0


## Ширина мира, если он шире экрана (уровень: камера ездит за игроком
## влево-вправо, как в Sky Force). 0 — мир по ширине экрана.
var world_width := 0.0


## Прямоугольник игрового мира: от (0, 0) до (ширина мира, высота экрана / zoom).
func rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size / zoom()
	if world_width > size.x:
		size.x = world_width
	return Rect2(Vector2.ZERO, size)


## Сколько мира видно на экране (без запаса по бокам).
func visible_size() -> Vector2:
	return get_viewport().get_visible_rect().size / zoom()


## Во сколько раз мир отдалён (1 — как есть, 0.8 — всё на 20% мельче).
func zoom() -> float:
	var camera := get_viewport().get_camera_2d()
	return camera.zoom.x if camera else 1.0


## Во сколько раз сдвиг пальца на экране (px) больше сдвига в мире.
## Обычно это zoom камеры; 3D-вид ставит свой масштаб (перспектива).
var drag_scale_override := 0.0


func drag_scale() -> float:
	return drag_scale_override if drag_scale_override > 0.0 else zoom()


## Видимая часть мира (с учётом сдвига камеры по горизонтали).
func visible_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var origin := Vector2(camera.position.x, 0.0) if camera else Vector2.ZERO
	return Rect2(origin, visible_size())


## Точка в кадре (с отступом от краёв) — отсюда врагам можно стрелять.
func is_in_view(point: Vector2, margin := 24.0) -> bool:
	return visible_rect().grow(-margin).has_point(point)


## Точка появления игрока (и цель манёвра «доворот на игрока» в превью).
func player_spawn_point() -> Vector2:
	var size := rect().size
	return Vector2(size.x / 2.0, size.y - PLAYER_SPAWN_FROM_BOTTOM)


## Самолёт внутри мира (с отступом ON_SCREEN_INSET) — «побывал в кадре».
func is_on_screen(point: Vector2) -> bool:
	return rect().grow(-ON_SCREEN_INSET).has_point(point)


## Пора убрать самолёт (врага в бою или его призрака в превью): побывал в
## кадре и улетел за край, или живёт дольше AIR_MAX_LIFETIME. Пока он в
## кадре — не убираем никогда (появляются враги за краем, поэтому сначала
## ждём, пока он хоть раз окажется в кадре).
func is_air_gone(point: Vector2, was_on_screen: bool, alive_time: float) -> bool:
	if is_on_screen(point):
		return false
	return (was_on_screen and not rect().grow(DESPAWN_MARGIN).has_point(point)) \
		or alive_time > AIR_MAX_LIFETIME


## Пора убрать наземного (уехал вниз вместе с землёй или живёт слишком долго).
func is_ground_gone(point: Vector2, alive_time: float) -> bool:
	return point.y > rect().size.y + GROUND_DESPAWN_MARGIN or alive_time > GROUND_MAX_LIFETIME
