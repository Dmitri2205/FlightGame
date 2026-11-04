extends Control
## Экран прокачки. Строки строятся по GameState.UPGRADES,
## так что новое улучшение достаточно описать там.

const STAR_ICON := preload("res://ui/star.svg")

@onready var stars_label: Label = %StarsLabel
@onready var list: VBoxContainer = %UpgradeList


func _ready() -> void:
	%BackButton.pressed.connect(Router.main_menu)
	GameState.stars_changed.connect(_on_stars_changed)
	GameState.upgrade_changed.connect(_on_upgrade_changed)
	_refresh()


func _on_stars_changed(_total: int) -> void:
	_refresh()


func _on_upgrade_changed(_id: String, _level: int) -> void:
	_refresh()


func _refresh() -> void:
	stars_label.text = "%d" % GameState.stars
	for child in list.get_children():
		child.queue_free()
	for id in GameState.UPGRADES:
		list.add_child(_make_row(id))


func _make_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var level := GameState.get_level(id)
	var title := Label.new()
	title.text = "%s  · ур. %d/%d" % [GameState.UPGRADES[id].title, level, GameState.get_max_level(id)]
	info.add_child(title)

	# Что модуль даёт сейчас и что изменится на следующем уровне.
	var now := Label.new()
	now.text = "Сейчас: " + GameState.describe_upgrade(id, level)
	now.add_theme_font_size_override("font_size", 22)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(now)
	if not GameState.is_maxed(id):
		var next := Label.new()
		next.text = "Дальше: " + GameState.describe_upgrade(id, level + 1)
		next.add_theme_font_size_override("font_size", 22)
		next.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(next)

	var bar := ProgressBar.new()
	bar.max_value = GameState.get_max_level(id)
	bar.value = GameState.get_level(id)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.custom_minimum_size = Vector2(0, 24)
	info.add_child(bar)

	var button := Button.new()
	button.custom_minimum_size = Vector2(200, 80)
	# PASS, чтобы список можно было листать, начав свайп на кнопке.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	if GameState.is_maxed(id):
		button.text = "МАКС"
		button.disabled = true
	else:
		button.text = "%d" % GameState.get_upgrade_cost(id)
		button.icon = STAR_ICON
		button.disabled = not GameState.can_upgrade(id)
		button.pressed.connect(GameState.try_upgrade.bind(id))
	row.add_child(button)

	return row
