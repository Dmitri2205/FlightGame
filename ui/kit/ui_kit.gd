class_name UiKit
extends RefCounted
## Общие кусочки интерфейса.

const STAR_ICON := preload("res://ui/kit/star.svg")
const CRYSTAL_ICON := preload("res://ui/kit/crystal.svg")
const BLUEPRINT_ICON := preload("res://ui/kit/blueprint.svg")
const CRYSTAL_COLOR := Color(0.45, 0.88, 1.0)


## Добавить в строку со звёздами счётчик кристаллов. Сам обновляется
## по GameState.crystals_changed. Возвращает метку с числом.
static func add_crystal_counter(row: Container, font_size := 48) -> Label:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var icon := TextureRect.new()
	icon.texture = CRYSTAL_ICON
	icon.custom_minimum_size = Vector2(font_size, font_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = "%d" % GameState.progress.crystals
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CRYSTAL_COLOR)
	row.add_child(label)
	var update := func(total: int) -> void:
		label.text = "%d" % total
	GameState.crystals_changed.connect(update)
	label.tree_exiting.connect(func() -> void: GameState.crystals_changed.disconnect(update))
	return label


## Бесконечная мягкая пульсация масштаба вокруг центра: до scale и обратно,
## half_period секунд в каждую сторону. Контрол должен быть уже в дереве сцены.
static func pulse(control: Control, scale: float, half_period: float) -> void:
	control.pivot_offset = control.size / 2.0
	control.resized.connect(func() -> void: control.pivot_offset = control.size / 2.0)
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "scale", Vector2.ONE * scale, half_period).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "scale", Vector2.ONE, half_period).set_trans(Tween.TRANS_SINE)
