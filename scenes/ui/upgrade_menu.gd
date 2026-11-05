extends Control
## Ангар: модули корабля. У модуля уровень (цифра в кружке) и шкала из 10
## делений: деления покупаются в характеристики (по 5 в каждую из двух или 10
## в одну). Заполнилась шкала — модуль переходит на следующий уровень.
## Строки строятся по GameState.MODULES.
## Вкладка «Чертежи» — сбор кораблей: прогресс и докупка кусков за кристаллы.
## Где лежат чертежи, не показываем — их надо искать на уровнях.

const STAR_ICON := preload("res://ui/star.svg")
const PIP_ON := Color(1, 0.8, 0.3)
const PIP_OFF := Color(1, 1, 1, 0.15)

@onready var stars_label: Label = %StarsLabel
@onready var list: VBoxContainer = %UpgradeList

var _tab := "modules"
var _tab_buttons := {}


func _ready() -> void:
	%BackButton.pressed.connect(Router.main_menu)
	UiKit.add_crystal_counter(%StarsLabel.get_parent())
	_build_tabs()
	GameState.crystals_changed.connect(_on_stars_changed)
	GameState.blueprints_changed.connect(_on_blueprints_changed)
	GameState.stars_changed.connect(_on_stars_changed)
	GameState.upgrade_changed.connect(_on_upgrade_changed)
	_refresh()
	if GameState.legacy_refund > 0:
		_show_refund_note(GameState.legacy_refund)
		GameState.legacy_refund = 0


func _on_stars_changed(_total: int) -> void:
	_refresh()


func _on_upgrade_changed(_id: String, _tier: int) -> void:
	_refresh()


func _on_blueprints_changed(_ship_id: String, _count: int) -> void:
	_refresh()


## Две вкладки над списком: «Модули» и «Чертежи».
func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for tab in [["modules", "Модули"], ["blueprints", "Чертежи"]]:
		var button := Button.new()
		button.text = tab[1]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(tab[0]))
		row.add_child(button)
		_tab_buttons[tab[0]] = button
	var box := list.get_parent().get_parent() as Container
	box.add_child(row)
	box.move_child(row, list.get_parent().get_index())
	_select_tab(_tab)


func _select_tab(tab: String) -> void:
	_tab = tab
	for key in _tab_buttons:
		_tab_buttons[key].button_pressed = key == tab
	_refresh()


func _refresh() -> void:
	stars_label.text = "%d" % GameState.stars
	for child in list.get_children():
		child.queue_free()
	if _tab == "blueprints":
		_build_blueprints()
		return
	for id in GameState.MODULES:
		list.add_child(_make_card(id))


func _build_blueprints() -> void:
	var hint := Label.new()
	hint.text = "Чертежи прячутся в постройках захватчиков на уровнях. Найденный чертёж засчитывается, только если долететь до конца уровня."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	list.add_child(hint)
	for ship in GameState.ships:
		if ship.blueprints_required > 0:
			list.add_child(_make_blueprint_card(ship))


func _make_blueprint_card(ship: ShipData) -> Control:
	var owned := GameState.is_ship_unlocked(ship.id)
	var count := GameState.blueprint_count(ship.id)
	var complete := GameState.blueprints_complete(ship.id)

	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(box)

	# Силуэт: пока чертежи не собраны — затемнён.
	var picture := TextureRect.new()
	picture.texture = ship.texture
	picture.custom_minimum_size = Vector2(120, 120)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_PASS
	if not (owned or complete):
		picture.modulate = Color(0.15, 0.25, 0.45)
	box.add_child(picture)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(info)
	var title := Label.new()
	title.text = ship.title
	title.add_theme_color_override("font_color", ship.color.lightened(0.2))
	info.add_child(title)

	var progress := Label.new()
	progress.add_theme_font_size_override("font_size", 24)
	if owned:
		progress.text = "Корабль открыт"
	elif complete:
		progress.text = "Собран! Купи его в разделе «Корабли»"
	else:
		progress.text = "Чертежи: %d / %d" % [count, ship.blueprints_required]
	info.add_child(progress)

	var bar := ProgressBar.new()
	bar.max_value = ship.blueprints_required
	bar.value = ship.blueprints_required if owned else count
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(bar)

	if not (owned or complete):
		var cost := GameState.blueprint_crystal_cost(ship.id)
		var button := _buy_button("Докупить чертёж · %d" % cost, GameState.crystals >= cost, false)
		button.icon = UiKit.CRYSTAL_ICON
		button.expand_icon = false
		button.pressed.connect(GameState.try_buy_blueprint.bind(ship.id))
		info.add_child(button)
	return card


func _make_card(id: String) -> Control:
	var data: Dictionary = GameState.MODULES[id]
	var tier := GameState.module_tier(id)
	var max_tier := GameState.module_max_tier(id)

	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# Заголовок: уровень в кружке, название, что даёт текущий уровень.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(_tier_badge(tier))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = data.title
	titles.add_child(title)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	if tier == 0:
		sub.text = "Не установлен · откроет: " + GameState.describe_tier(id, 1)
	elif tier < max_tier:
		sub.text = "Ур. %d/%d: %s · дальше: %s" % [tier, max_tier, GameState.describe_tier(id, tier), GameState.describe_tier(id, tier + 1)]
	else:
		sub.text = "Ур. %d/%d (макс.): %s" % [tier, max_tier, GameState.describe_tier(id, tier)]
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(sub)
	header.add_child(titles)
	box.add_child(header)

	if tier == 0:
		var install := _buy_button("Установить %d" % GameState.install_cost(id), GameState.stars >= GameState.install_cost(id))
		install.pressed.connect(GameState.try_install.bind(id))
		box.add_child(install)
		return card

	# Шкала уровня: 10 делений.
	box.add_child(_pips(GameState.tier_progress(id), GameState.STEPS_PER_TIER, 12))

	# Характеристики: свои деления и кнопка покупки.
	for stat in data.stats:
		box.add_child(_stat_row(id, stat, data.stats[stat]))
	return card


func _stat_row(id: String, stat: String, stat_title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = "%s — %s" % [stat_title, GameState.describe_stat(id, stat)]
	label.add_theme_font_size_override("font_size", 24)
	info.add_child(label)
	info.add_child(_pips(GameState.stat_steps(id, stat), GameState.steps_per_stat(id), 8))
	row.add_child(info)

	var button: Button
	if GameState.is_maxed(id):
		button = _buy_button("МАКС", false, false)
	elif GameState.stat_full(id, stat):
		button = _buy_button("Готово", false, false)
	else:
		button = _buy_button("%d" % GameState.step_cost(id), GameState.can_buy_step(id, stat))
		button.pressed.connect(GameState.try_buy_step.bind(id, stat))
	button.custom_minimum_size = Vector2(170, 72)
	row.add_child(button)
	return row


func _buy_button(text: String, enabled: bool, with_star := true) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, 72)
	# PASS, чтобы список можно было листать, начав свайп на кнопке.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	if with_star:
		button.icon = STAR_ICON
	return button


## Цифра уровня в кружке, как в ангаре оригинала.
func _tier_badge(tier: int) -> Control:
	var badge := Label.new()
	badge.text = str(tier) if tier > 0 else "–"
	badge.custom_minimum_size = Vector2(64, 64)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 34)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.18, 0.05) if tier > 0 else Color(0.12, 0.12, 0.15)
	style.border_color = PIP_ON if tier > 0 else Color(1, 1, 1, 0.25)
	style.set_border_width_all(4)
	style.set_corner_radius_all(32)
	badge.add_theme_stylebox_override("normal", style)
	return badge


## Ряд делений: заполненные — золотые.
func _pips(filled: int, total: int, height: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in total:
		var pip := ColorRect.new()
		pip.color = PIP_ON if i < filled else PIP_OFF
		pip.custom_minimum_size = Vector2(0, height)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(pip)
	return row


func _show_refund_note(amount: int) -> void:
	var note := Label.new()
	note.text = "Прокачка теперь по уровням модулей. Потраченные звёзды возвращены: +%d" % amount
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", PIP_ON)
	note.add_theme_font_size_override("font_size", 24)
	%StarsLabel.get_parent().get_parent().add_child(note)
	%StarsLabel.get_parent().get_parent().move_child(note, 1)
