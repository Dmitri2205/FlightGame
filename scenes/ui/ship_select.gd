extends Control
## Выбор и покупка кораблей. Карточки строятся по GameState.ships.

## Значения, которые соответствуют полной полосе характеристики.
const STAT_MAX := {
	"speed": 1600.0,
	"agility": 12000.0,
	"armor": 8.0,
	"firepower": 2.5,
}

@onready var stars_label: Label = %StarsLabel
@onready var list: VBoxContainer = %ShipList


func _ready() -> void:
	%BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	GameState.stars_changed.connect(_on_stars_changed)
	GameState.ship_changed.connect(_on_ship_changed)
	_refresh()


func _on_stars_changed(_total: int) -> void:
	_refresh()


func _on_ship_changed(_id: String) -> void:
	_refresh()


func _refresh() -> void:
	stars_label.text = "★ %d" % GameState.stars
	for child in list.get_children():
		child.queue_free()
	for ship in GameState.ships:
		list.add_child(_make_card(ship))


func _make_card(ship: ShipData) -> Control:
	var card := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var title := Label.new()
	title.text = ship.title
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", ship.color.lightened(0.2))
	box.add_child(title)

	var description := Label.new()
	description.text = ship.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 24)
	box.add_child(description)

	var firepower := (1 + ship.damage_bonus) * ship.fire_rate_mult
	box.add_child(_make_stat("Скорость", ship.max_speed / STAT_MAX.speed))
	box.add_child(_make_stat("Манёвренность", ship.acceleration() / STAT_MAX.agility))
	box.add_child(_make_stat("Прочность", ship.base_health / STAT_MAX.armor))
	box.add_child(_make_stat("Огневая мощь", firepower / STAT_MAX.firepower))

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 80)
	if ship.id == GameState.selected_ship_id:
		button.text = "Выбран"
		button.disabled = true
	elif GameState.is_ship_unlocked(ship.id):
		button.text = "Выбрать"
		button.pressed.connect(GameState.select_ship.bind(ship.id))
	else:
		button.text = "Купить ★ %d" % ship.cost
		button.disabled = GameState.stars < ship.cost
		button.pressed.connect(GameState.try_unlock_ship.bind(ship.id))
	box.add_child(button)

	return card


func _make_stat(label_text: String, ratio: float) -> Control:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(260, 0)
	label.add_theme_font_size_override("font_size", 24)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.value = clampf(ratio, 0.0, 1.0) * 100.0
	row.add_child(bar)

	return row
