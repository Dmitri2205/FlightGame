extends Control
## Экран прокачки. Строки строятся по GameState.UPGRADES,
## так что новое улучшение достаточно описать там.

@onready var stars_label: Label = %StarsLabel
@onready var list: VBoxContainer = %UpgradeList


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	GameState.stars_changed.connect(_on_stars_changed)
	GameState.upgrade_changed.connect(_on_upgrade_changed)
	_refresh()


func _on_stars_changed(_total: int) -> void:
	_refresh()


func _on_upgrade_changed(_id: String, _level: int) -> void:
	_refresh()


func _refresh() -> void:
	stars_label.text = "★ %d" % GameState.stars
	for child in list.get_children():
		child.queue_free()
	for id in GameState.UPGRADES:
		list.add_child(_make_row(id))


func _make_row(id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = GameState.UPGRADES[id].title
	info.add_child(title)

	var bar := ProgressBar.new()
	bar.max_value = GameState.get_max_level(id)
	bar.value = GameState.get_level(id)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 24)
	info.add_child(bar)

	var button := Button.new()
	button.custom_minimum_size = Vector2(200, 80)
	if GameState.is_maxed(id):
		button.text = "МАКС"
		button.disabled = true
	else:
		button.text = "★ %d" % GameState.get_upgrade_cost(id)
		button.disabled = not GameState.can_upgrade(id)
		button.pressed.connect(GameState.try_upgrade.bind(id))
	row.add_child(button)

	return row
