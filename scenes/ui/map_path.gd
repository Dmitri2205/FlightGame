extends Control
## Пунктирная дорожка между уровнями на карте.

var points := PackedVector2Array()
## Сколько отрезков от начала уже пройдено (рисуются ярче).
var completed_segments := 0
var color := Color.WHITE


func _draw() -> void:
	for i in range(points.size() - 1):
		var done := i < completed_segments
		var segment_color := color if done else Color(1, 1, 1, 0.35)
		draw_dashed_line(points[i], points[i + 1], segment_color, 6.0 if done else 4.0, 18.0)
