extends Node
## Размер игрового мира в его собственных координатах. Подключено как
## autoload `Arena`.
##
## Камера уровня отдалена (Camera2D.zoom < 1): мир больше экрана, объекты на
## экране мельче, поле боя «шире». Поэтому всё игровое (границы, точки
## появления, выход за край) считается от Arena.rect(), а не от
## get_viewport_rect(). Камера стоит в (0, 0) с якорем в левом верхнем углу.
## Без камеры (меню, превью) мир совпадает с экраном.


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
