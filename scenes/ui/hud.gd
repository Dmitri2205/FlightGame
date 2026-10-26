extends CanvasLayer
## Интерфейс во время полёта: очки, прогресс уровня, здоровье, звёзды, итоги.

signal menu_requested

@onready var score_label: Label = %ScoreLabel
@onready var progress_bar: ProgressBar = %LevelProgress
@onready var health_bar: ProgressBar = %HealthBar
@onready var stars_label: Label = %StarsLabel
@onready var results_panel: PanelContainer = %ResultsPanel
@onready var results_title: Label = %ResultsTitle
@onready var results_stats: Label = %ResultsStats


func _ready() -> void:
	results_panel.hide()
	%MenuButton.pressed.connect(menu_requested.emit)
	%ResultsMenuButton.pressed.connect(menu_requested.emit)


func set_score(value: int) -> void:
	score_label.text = "%09d" % value


func set_progress(ratio: float) -> void:
	progress_bar.value = clampf(ratio, 0.0, 1.0) * 100.0


func set_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func set_stars(value: int) -> void:
	stars_label.text = "★ %d" % value


func show_results(victory: bool, score: int, stars: int) -> void:
	results_title.text = "Уровень пройден!" if victory else "Корабль сбит"
	results_stats.text = "Очки: %d\nЗвёзды: +%d\nВсего звёзд: %d" % [score, stars, GameState.stars]
	results_panel.show()
