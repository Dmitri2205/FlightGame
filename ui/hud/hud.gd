extends CanvasLayer
## Интерфейс во время полёта: очки, прогресс уровня, здоровье, звёзды, итоги.

signal menu_requested
signal retry_requested
signal next_requested

@onready var score_label: Label = %ScoreLabel
@onready var progress_bar: ProgressBar = %LevelProgress
@onready var health_bar: ProgressBar = %HealthBar
@onready var stars_label: Label = %StarsLabel
@onready var results_panel: PanelContainer = %ResultsPanel
@onready var results_title: Label = %ResultsTitle
@onready var results_stats: Label = %ResultsStats
@onready var boss_box: Control = %BossBox
@onready var boss_bar: ProgressBar = %BossBar


func _ready() -> void:
	results_panel.hide()
	boss_box.hide()
	# «II» — пауза, а не выход: уровень замирает, прогресс не теряется.
	%MenuButton.pressed.connect(pause)
	%ResumeButton.pressed.connect(resume)
	%PauseRetryButton.pressed.connect(retry_requested.emit)
	%PauseMapButton.pressed.connect(menu_requested.emit)
	%MusicButton.pressed.connect(_toggle_music)
	_update_music_button()
	%PausePanel.hide()
	%ResultsMenuButton.pressed.connect(menu_requested.emit)
	%RetryButton.pressed.connect(retry_requested.emit)
	%NextButton.pressed.connect(next_requested.emit)
	%Banner.hide()
	_build_blueprint_badge()


func set_score(value: int) -> void:
	score_label.text = "%09d" % value


func set_progress(ratio: float) -> void:
	progress_bar.value = clampf(ratio, 0.0, 1.0) * 100.0


## Здоровье — полоска и проценты; цвет от зелёного к красному.
func set_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	var ratio := float(current) / maxf(maximum, 1.0)
	var label: Label = %HealthLabel
	label.text = "%d%%" % roundi(ratio * 100.0)
	var color := Color(0.45, 1.0, 0.45) if ratio > 0.6 else (Color(1.0, 0.85, 0.3) if ratio > 0.3 else Color(1.0, 0.35, 0.3))
	health_bar.modulate = color
	label.add_theme_color_override("font_color", color)


func set_stars(value: int) -> void:
	stars_label.text = "%d" % value


func show_boss(max_hp: int, title := "БОСС") -> void:
	(%BossLabel as Label).text = title
	boss_bar.max_value = max_hp
	boss_bar.value = max_hp
	boss_box.show()


func set_boss_health(current: int, maximum: int) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current


func hide_boss() -> void:
	boss_box.hide()


## Название уровня по центру экрана в начале — плавно появляется и гаснет.
func show_banner(text: String) -> void:
	var banner: Label = %Banner
	banner.text = text
	banner.modulate.a = 0.0
	banner.show()
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.8)
	tween.tween_property(banner, "modulate:a", 0.0, 0.6)
	tween.tween_callback(banner.hide)


## Пауза: вся игра замирает (HUD работает и на паузе — process_mode ALWAYS).
func pause() -> void:
	if results_panel.visible or get_tree().paused:
		return
	get_tree().paused = true
	%PausePanel.show()


func resume() -> void:
	get_tree().paused = false
	%PausePanel.hide()


func _toggle_music() -> void:
	GameState.set_music(not GameState.music_on)
	_update_music_button()


func _update_music_button() -> void:
	(%MusicButton as Button).text = "Музыка: вкл" if GameState.music_on else "Музыка: выкл"


func is_paused() -> bool:
	return %PausePanel.visible


## Значок «чертёж на борту»: подобран, но засчитается только в конце уровня.
var _blueprint_badge: HBoxContainer


func _build_blueprint_badge() -> void:
	_blueprint_badge = HBoxContainer.new()
	_blueprint_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blueprint_badge.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = preload("res://ui/kit/blueprint.svg")
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_blueprint_badge.add_child(icon)
	var label := Label.new()
	label.name = "Text"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_blueprint_badge.add_child(label)
	# Под строкой звёзд (StarsLabel → StarsRow → Top).
	stars_label.get_parent().get_parent().add_child(_blueprint_badge)
	_blueprint_badge.hide()


func show_blueprint(ship_title: String) -> void:
	(_blueprint_badge.get_node("Text") as Label).text = "Чертёж «%s» — долети до конца!" % ship_title
	_blueprint_badge.show()
	var tween := create_tween().set_loops(3)
	tween.tween_property(_blueprint_badge, "modulate:a", 0.3, 0.2)
	tween.tween_property(_blueprint_badge, "modulate:a", 1.0, 0.2)


func show_results(victory: bool, score: int, stars: int, bonus: int, has_next: bool, crystals := 0, blueprint_line := "") -> void:
	results_title.text = "Уровень пройден!" if victory else "Корабль сбит"
	var lines := PackedStringArray(["Очки: %d" % score, "Звёзды: +%d" % stars])
	if bonus > 0:
		lines.append("Бонус за прохождение: +%d" % bonus)
	if crystals > 0:
		lines.append("Кристаллы: +%d" % crystals)
	if blueprint_line != "":
		lines.append(blueprint_line)
	lines.append("Всего звёзд: %d · кристаллов: %d" % [GameState.stars, GameState.crystals])
	results_stats.text = "\n".join(lines)
	%NextButton.visible = has_next
	%PausePanel.hide()
	get_tree().paused = false
	results_panel.show()
