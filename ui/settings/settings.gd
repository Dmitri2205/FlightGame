extends Control
## Настройки. Разделы строятся кодом: новый раздел — _add_section(),
## строки в нём — _add_slider() (или новые строители рядом).
## Значения живут в GameState.settings и сохраняются вместе с игрой.

const HEADER_COLOR := Color(1, 0.82, 0.35)
## Высота ползунка — под палец.
const SLIDER_HEIGHT := 72


func _ready() -> void:
	%BackButton.pressed.connect(Router.main_menu)
	var sound := _add_section("Звук")
	_add_slider(sound, "Музыка", GameState.settings.music_volume, GameState.set_music_volume)
	_add_slider(sound, "Эффекты", GameState.settings.sfx_volume, GameState.set_sfx_volume)


## Уйти с экрана посреди перетаскивания — значение всё равно сохранится.
func _exit_tree() -> void:
	GameState.save_game()


## Карточка раздела с заголовком. Возвращает контейнер для строк раздела.
func _add_section(title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	%Sections.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 40)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	box.add_child(header)
	return box


## Ползунок громкости 0–100 % с подписью. setter(volume: float, save: bool):
## при перетаскивании громкость применяется сразу, сохраняется — когда отпустили.
func _add_slider(section: VBoxContainer, title: String, volume: float, setter: Callable) -> HSlider:
	var top := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var percent := Label.new()
	top.add_child(percent)
	section.add_child(top)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(0, SLIDER_HEIGHT)
	slider.value = roundf(volume * 100.0)
	percent.text = _percent(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		percent.text = _percent(value)
		setter.call(value / 100.0, false))
	slider.drag_ended.connect(func(_changed: bool) -> void: GameState.save_game())
	section.add_child(slider)
	return slider


static func _percent(value: float) -> String:
	return "%d%%" % roundi(value)
