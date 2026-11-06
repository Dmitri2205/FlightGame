extends Control
## Главное меню. Живой фон: планета текущей главы, облака, свой корабль
## (его можно водить пальцем) и пролетающие волны врагов-призраков
## (тот же WaveDirector и GhostFlock, что в превью). «Играть» ведёт на карту.
## Отладочные кнопки спрятаны в блоке «Разработчику», а сам блок от игрока:
## в собранной игре он появляется после 7 быстрых тапов по названию.

## Пауза между волнами-призраками на фоне, секунд.
const DEMO_WAVE_INTERVAL := 3.5
const DEV_UNLOCK_TAPS := 7
## Кнопка «Играть» мягко пульсирует: масштаб и полупериод, с.
const PLAY_PULSE_SCALE := 1.04
const PLAY_PULSE_HALF_PERIOD := 0.8

var _title_taps := 0

var _reset_armed := false

@onready var ghosts: GhostFlock = $Ghosts
@onready var director: WaveDirector = $WaveDirector
@onready var player = $Player


func _ready() -> void:
	var chapter := GameState.current_chapter_data()
	var next := GameState.next_level_to_play()
	var next_chapter := GameState.get_chapter(next[0])
	var next_level: LevelData = next_chapter.levels[next[1]]

	%StarsLabel.text = "%d" % GameState.progress.stars
	UiKit.add_crystal_counter(%StarsLabel.get_parent(), 36)
	# Разработчику: кристаллы для проверки докупки чертежей.
	var crystals_button := Button.new()
	crystals_button.text = "+20 кристаллов"
	crystals_button.custom_minimum_size = Vector2(0, 64)
	crystals_button.pressed.connect(GameState.add_crystals.bind(20))
	%DevPanel.add_child(crystals_button)
	# Разработчику: прототип 2.5D-вида уровня.
	var view_button := Button.new()
	view_button.custom_minimum_size = Vector2(0, 64)
	view_button.text = _view_3d_text()
	view_button.pressed.connect(func() -> void:
		GameState.set_view_3d(not GameState.settings.view_3d)
		view_button.text = _view_3d_text())
	%DevPanel.add_child(view_button)

	# Версия сборки в углу: если на сайте новое, а тут старое — это кэш браузера.
	var version := Label.new()
	var version_text := "dev"
	if FileAccess.file_exists("res://build_version.txt"):
		version_text = FileAccess.get_file_as_string("res://build_version.txt").strip_edges()
	version.text = "сборка " + version_text
	version.add_theme_font_size_override("font_size", 18)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(version)
	%ChapterLabel.text = "%s · %s" % [chapter.title, chapter.planet]
	%ChapterLabel.add_theme_color_override("font_color", chapter.color)
	%NextLabel.text = "Следующий: %s · %d. %s" % [next_chapter.planet, next[1] + 1, next_level.title]

	var ship := GameState.get_selected_ship()
	%ShipsButton.text = ship.title
	%ShipsButton.icon = ship.texture

	%PlayButton.pressed.connect(_play.bind(next[0]))
	%ShipsButton.pressed.connect(Router.ships)
	%UpgradesButton.pressed.connect(Router.upgrades)
	%SettingsButton.pressed.connect(Router.settings)
	%PreviewButton.pressed.connect(Router.wave_preview)
	%BossTestButton.pressed.connect(_start_test.bind(true))
	%PatternTestButton.pressed.connect(_start_test.bind(false))
	%ResetButton.pressed.connect(_on_reset_pressed)
	%DevToggle.pressed.connect(_toggle_dev_panel)
	%DevPanel.hide()
	%DevToggle.visible = GameState.dev_tools_available()
	%Title.gui_input.connect(_on_title_input)
	UiKit.pulse(%PlayButton, PLAY_PULSE_SCALE, PLAY_PULSE_HALF_PERIOD)

	# Корабль-витрина: летает и стреляет, можно водить пальцем.
	var screen := get_viewport_rect().size
	player.place_at(Vector2(screen.x / 2.0, screen.y * 0.6))
	player.projectile_container = $Projectiles

	# Фоновые волны — бесконечный «уровень» из всех волн библиотеки.
	var demo := LevelData.new()
	demo.duration = 1.0e9
	demo.filler_waves = DataLibrary.waves()
	demo.filler_from = 1.0
	demo.rest_min = DEMO_WAVE_INTERVAL
	demo.rest_max = DEMO_WAVE_INTERVAL * 2.0
	ghosts.opacity = 0.7
	director.enemy_requested.connect(ghosts.spawn_for_wave)
	director.start(demo)


func _process(delta: float) -> void:
	if is_instance_valid(player):
		ghosts.target = player.global_position
	ghosts.advance(delta)


func _play(chapter: int) -> void:
	GameState.select_chapter(chapter)
	Router.level_map()


func _start_test(boss: bool) -> void:
	if boss:
		GameState.boss_test = true
	else:
		GameState.pattern_test = true
	Router.level()


func _toggle_dev_panel() -> void:
	%DevPanel.visible = not %DevPanel.visible
	%DevToggle.text = "Разработчику –" if %DevPanel.visible else "Разработчику +"


## Секрет: 7 быстрых тапов по названию включают/выключают инструменты разработчика.
func _on_title_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_title_taps += 1
	if _title_taps == 1:
		get_tree().create_timer(2.5).timeout.connect(func(): _title_taps = 0)
	if _title_taps >= DEV_UNLOCK_TAPS:
		_title_taps = 0
		GameState.set_dev_mode(not GameState.settings.dev_mode)
		%DevToggle.visible = GameState.dev_tools_available()
		if not %DevToggle.visible:
			%DevPanel.hide()
		%NextLabel.text = "Режим разработчика: %s" % ("включён" if GameState.settings.dev_mode else "выключен")


## Сброс — в два нажатия, чтобы не стереть прогресс случайно.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		%ResetButton.text = "Точно? Ещё раз"
		get_tree().create_timer(3.0).timeout.connect(_disarm_reset)
		return
	GameState.reset_progress()
	Router.reload()


func _disarm_reset() -> void:
	_reset_armed = false
	if is_instance_valid(%ResetButton):
		%ResetButton.text = "Сбросить прогресс"


static func _view_3d_text() -> String:
	return "3D-вид: вкл" if GameState.settings.view_3d else "3D-вид: выкл"
