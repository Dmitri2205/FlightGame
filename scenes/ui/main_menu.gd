extends Control
## Главное меню. Живой фон: планета текущей главы, облака, свой корабль
## (его можно водить пальцем) и пролетающие волны врагов-призраков
## (тот же WaveDirector и GhostFlock, что в превью). «Играть» ведёт на карту.
## Отладочные кнопки спрятаны в блоке «Разработчику», а сам блок от игрока:
## в собранной игре он появляется после 7 быстрых тапов по названию.

## Пауза между волнами-призраками на фоне, секунд.
const DEMO_WAVE_INTERVAL := 3.5
const DEV_UNLOCK_TAPS := 7

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

	%StarsLabel.text = "%d" % GameState.stars
	UiKit.add_crystal_counter(%StarsLabel.get_parent(), 36)
	# Разработчику: кристаллы для проверки докупки чертежей.
	var crystals_button := Button.new()
	crystals_button.text = "+20 кристаллов"
	crystals_button.custom_minimum_size = Vector2(0, 64)
	crystals_button.pressed.connect(GameState.add_crystals.bind(20))
	%DevPanel.add_child(crystals_button)
	%ChapterLabel.text = "%s · %s" % [chapter.title, chapter.planet]
	%ChapterLabel.add_theme_color_override("font_color", chapter.color)
	%NextLabel.text = "Следующий: %s · %d. %s" % [next_chapter.planet, next[1] + 1, next_level.title]

	var ship := GameState.get_selected_ship()
	%ShipsButton.text = ship.title
	%ShipsButton.icon = ship.texture

	%PlayButton.pressed.connect(_play.bind(next[0]))
	%ShipsButton.pressed.connect(Router.ships)
	%UpgradesButton.pressed.connect(Router.upgrades)
	%PreviewButton.pressed.connect(Router.wave_preview)
	%BossTestButton.pressed.connect(_start_test.bind(true))
	%PatternTestButton.pressed.connect(_start_test.bind(false))
	%ResetButton.pressed.connect(_on_reset_pressed)
	%DevToggle.pressed.connect(_toggle_dev_panel)
	%DevPanel.hide()
	%DevToggle.visible = GameState.dev_tools_available()
	%Title.gui_input.connect(_on_title_input)
	_pulse(%PlayButton)

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
		GameState.set_dev_mode(not GameState.dev_mode)
		%DevToggle.visible = GameState.dev_tools_available()
		if not %DevToggle.visible:
			%DevPanel.hide()
		%NextLabel.text = "Режим разработчика: %s" % ("включён" if GameState.dev_mode else "выключен")


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


## Кнопка «Играть» мягко пульсирует.
func _pulse(button: Control) -> void:
	button.resized.connect(func(): button.pivot_offset = button.size / 2.0)
	var tween := button.create_tween().set_loops()
	tween.tween_property(button, "scale", Vector2.ONE * 1.04, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(button, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
