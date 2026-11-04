extends Control
## Карта уровней: главы-планеты, уровни на извилистой дорожке снизу вверх.
## Уровень открывается после прохождения предыдущего, глава — после финала прошлой.

const NODE_SIZE := 112.0
const BOSS_NODE_SIZE := 140.0
## Горизонтальные позиции узлов (доли ширины) — дорожка петляет.
const NODE_X := [0.5, 0.74, 0.3, 0.66, 0.36, 0.7]

@onready var background: Node2D = $Background
@onready var path: Control = $Path
@onready var nodes: Control = $Nodes
@onready var chapter_label: Label = %ChapterLabel
@onready var planet_label: Label = %PlanetLabel
@onready var description_label: Label = %DescriptionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var locked_label: Label = %LockedLabel


func _ready() -> void:
	%StarsLabel.text = "%d" % GameState.stars
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	%PrevButton.pressed.connect(_switch_chapter.bind(-1))
	%NextButton.pressed.connect(_switch_chapter.bind(1))
	_show_chapter()


func _switch_chapter(step: int) -> void:
	GameState.select_chapter(GameState.current_chapter + step)
	_show_chapter()


func _show_chapter() -> void:
	var index := GameState.current_chapter
	var chapter := GameState.current_chapter_data()
	var unlocked := GameState.is_chapter_unlocked(index)

	background.apply_chapter(chapter)
	chapter_label.text = chapter.title
	planet_label.text = chapter.planet
	planet_label.add_theme_color_override("font_color", chapter.color)
	description_label.text = chapter.description
	locked_label.visible = not unlocked
	%PrevButton.disabled = index == 0
	%NextButton.disabled = index == GameState.chapters.size() - 1

	var done := 0
	for i in chapter.levels.size():
		if GameState.is_level_completed(index, i):
			done += 1
	progress_label.text = "Пройдено %d из %d" % [done, chapter.levels.size()]

	_build_nodes(index, chapter)


func _build_nodes(index: int, chapter: ChapterData) -> void:
	for child in nodes.get_children():
		child.queue_free()

	var size := get_viewport_rect().size
	var top := 470.0
	var bottom := size.y - 250.0
	var count: int = chapter.levels.size()
	var points := PackedVector2Array()
	var completed_segments := 0

	for i in count:
		var level: LevelData = chapter.levels[i]
		var t := 0.0 if count == 1 else float(i) / (count - 1)
		var x: float = 0.5 if level.boss else NODE_X[i % NODE_X.size()]
		var center := Vector2(x * size.x, lerpf(bottom, top, t))
		points.append(center)
		if GameState.is_level_completed(index, i) and i < count - 1:
			completed_segments = i + 1
		nodes.add_child(_make_node(index, i, level, center, chapter.color))

	path.points = points
	path.completed_segments = completed_segments
	path.color = chapter.color
	path.queue_redraw()


func _make_node(chapter_index: int, level_index: int, level: LevelData, center: Vector2, accent: Color) -> Control:
	var completed := GameState.is_level_completed(chapter_index, level_index)
	var unlocked := GameState.is_level_unlocked(chapter_index, level_index)
	var diameter := BOSS_NODE_SIZE if level.boss else NODE_SIZE

	var holder := Control.new()
	holder.position = center
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var button := Button.new()
	button.text = "БОСС" if level.boss else str(level_index + 1)
	button.add_theme_font_size_override("font_size", 30 if level.boss else 44)
	button.size = Vector2(diameter, diameter)
	button.position = -button.size / 2.0
	button.pivot_offset = button.size / 2.0
	button.disabled = not unlocked
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _node_style(completed, unlocked, accent, state))
	button.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(1, 1, 1, 0.35))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	button.pressed.connect(_start_level.bind(chapter_index, level_index))
	holder.add_child(button)

	# Уровень, который ждёт прохождения, мягко пульсирует
	# (твин можно создать только когда кнопка уже в дереве сцены).
	if unlocked and not completed:
		button.tree_entered.connect(_pulse.bind(button), CONNECT_ONE_SHOT)

	var caption := Label.new()
	caption.text = level.title
	if completed:
		caption.text += "\nрекорд: %d" % GameState.best_score(chapter_index, level_index)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	caption.add_theme_constant_override("outline_size", 8)
	caption.modulate.a = 1.0 if unlocked else 0.5
	caption.size = Vector2(260, 70)
	caption.position = Vector2(-130, diameter / 2.0 + 6.0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(caption)
	return holder


func _pulse(button: Button) -> void:
	var tween := button.create_tween().set_loops()
	tween.tween_property(button, "scale", Vector2.ONE * 1.08, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(button, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func _node_style(completed: bool, unlocked: bool, accent: Color, state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(BOSS_NODE_SIZE))
	style.set_border_width_all(5)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	if not unlocked:
		style.bg_color = Color(0.15, 0.15, 0.18, 0.85)
		style.border_color = Color(1, 1, 1, 0.2)
	elif completed:
		style.bg_color = accent.darkened(0.35)
		style.border_color = accent
	else:
		style.bg_color = Color(0.1, 0.12, 0.18, 0.9)
		style.border_color = accent.lightened(0.3)
		style.set_border_width_all(7)
	if state == "pressed":
		style.bg_color = style.bg_color.lightened(0.2)
	return style


func _start_level(chapter_index: int, level_index: int) -> void:
	GameState.select_level(chapter_index, level_index)
	get_tree().change_scene_to_file("res://scenes/game/level.tscn")
