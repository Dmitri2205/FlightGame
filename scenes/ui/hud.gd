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
	%PausePanel.hide()
	%ResultsMenuButton.pressed.connect(menu_requested.emit)
	%RetryButton.pressed.connect(retry_requested.emit)
	%NextButton.pressed.connect(next_requested.emit)
	%Banner.hide()


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


func show_boss(max_hp: int) -> void:
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


func is_paused() -> bool:
	return %PausePanel.visible


func show_results(victory: bool, score: int, stars: int, bonus: int, has_next: bool) -> void:
	results_title.text = "Уровень пройден!" if victory else "Корабль сбит"
	var lines := PackedStringArray(["Очки: %d" % score, "Звёзды: +%d" % stars])
	if bonus > 0:
		lines.append("Бонус за прохождение: +%d" % bonus)
	lines.append("Всего звёзд: %d" % GameState.stars)
	results_stats.text = "\n".join(lines)
	%NextButton.visible = has_next
	%PausePanel.hide()
	get_tree().paused = false
	results_panel.show()
