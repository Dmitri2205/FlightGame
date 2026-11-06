extends Control
## Превью волн — смотреть на телефоне, как летают враги, без редактора.
##
## «Траектории»: путь каждой траектории из data/patterns (сплошной — обычный,
## пунктир — зеркальный), точка появления, манёвры и «призраки» на пути.
## «Уровни»: таймлайн уровня и проигрывание волн тем же WaveDirector, что в бою,
## — враги-призраки без стрельбы и столкновений, следы их путей, шкала времени.
##
## Пути считаются тем же PatternMotion, что двигает врагов в игре.

enum Mode { PATTERNS, LEVELS }

const SPEEDS := [1.0, 2.0, 4.0]
const SIM_STEP := 1.0 / 60.0
const PATTERN_SPEED := 260.0
const TRAIL_LIFETIME := 6.0
const COLOR_MAIN := Color(1.0, 0.85, 0.3)
const COLOR_MIRROR := Color(0.45, 0.85, 1.0)

var mode := Mode.PATTERNS
var playing := true
var speed_index := 0

var _patterns: Array[FlightPattern] = []
var _pattern_index := 0
## [[глава, уровень], ...] — все уровни подряд.
var _levels: Array = []
var _level_index := 0

## Пути для рисования: [{points, color, dashed, age}]
var _paths: Array[Dictionary] = []
var _ghost_timer := 0.0

@onready var background: Node2D = $Background
@onready var overlay: Control = $Overlay
@onready var ghosts: GhostFlock = $Ghosts
@onready var director: WaveDirector = $WaveDirector
@onready var title_label: Label = %TitleLabel
@onready var info_label: Label = %InfoLabel
@onready var time_label: Label = %TimeLabel


func _ready() -> void:
	_patterns = DataLibrary.patterns()
	for c in GameState.chapters.size():
		for l in GameState.get_chapter(c).levels.size():
			_levels.append([c, l])
	_level_index = maxi(0, _levels.find([GameState.current_chapter, GameState.current_level]))

	ghosts.target = _player_spot()
	overlay.draw.connect(_draw_overlay)
	director.enemy_requested.connect(_on_enemy_requested)
	director.wave_started.connect(_on_wave_started)
	%PatternsTab.pressed.connect(_set_mode.bind(Mode.PATTERNS))
	%LevelsTab.pressed.connect(_set_mode.bind(Mode.LEVELS))
	%PrevButton.pressed.connect(_select.bind(-1))
	%NextButton.pressed.connect(_select.bind(1))
	%PlayButton.pressed.connect(_toggle_play)
	%SpeedButton.pressed.connect(_cycle_speed)
	%RestartButton.pressed.connect(_restart)
	%BackButton.pressed.connect(Router.main_menu)
	_set_mode(Mode.PATTERNS)


func _process(delta: float) -> void:
	if not playing:
		return
	var dt: float = delta * SPEEDS[speed_index]
	director.speed_scale = SPEEDS[speed_index]

	if mode == Mode.PATTERNS:
		_ghost_timer -= dt
		if _ghost_timer <= 0.0 and not _patterns.is_empty():
			_ghost_timer = 0.9
			ghosts.spawn(_patterns[_pattern_index], PATTERN_SPEED)
			ghosts.spawn(_patterns[_pattern_index].mirrored(), PATTERN_SPEED)
	else:
		for path in _paths:
			path.age += dt
		var kept: Array[Dictionary] = []
		kept.assign(_paths.filter(func(p): return p.age < TRAIL_LIFETIME))
		_paths = kept
		_update_time_label()

	ghosts.advance(dt)
	overlay.queue_redraw()


# --- Режимы и выбор -----------------------------------------------------------

func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	%PatternsTab.disabled = mode == Mode.PATTERNS
	%LevelsTab.disabled = mode == Mode.LEVELS
	time_label.visible = mode == Mode.LEVELS
	_restart()


func _select(step: int) -> void:
	if mode == Mode.PATTERNS:
		_pattern_index = wrapi(_pattern_index + step, 0, _patterns.size())
	else:
		_level_index = wrapi(_level_index + step, 0, _levels.size())
	_restart()


func _toggle_play() -> void:
	playing = not playing
	director.set_process(playing)
	%PlayButton.text = "Пауза" if playing else "Пуск"


func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	%SpeedButton.text = "×%d" % int(SPEEDS[speed_index])


func _restart() -> void:
	ghosts.clear()
	_paths.clear()
	_ghost_timer = 0.0
	director.stop()
	if mode == Mode.PATTERNS:
		_show_pattern()
	else:
		_show_level()
	overlay.queue_redraw()


func _show_pattern() -> void:
	if _patterns.is_empty():
		title_label.text = "Нет траекторий в data/patterns"
		return
	var pattern := _patterns[_pattern_index]
	background.apply_chapter(GameState.current_chapter_data())
	title_label.text = "%d/%d · %s" % [_pattern_index + 1, _patterns.size(), pattern.title]
	var lines := PackedStringArray()
	lines.append("%s · старт x=%.2f y=%d · курс %d°" % [pattern.resource_path.get_file().get_basename(), pattern.start.x, pattern.start.y, pattern.heading])
	for i in pattern.steps.size():
		lines.append("%d. %s" % [i + 1, _describe_step(pattern.steps[i])])
	lines.append("— дальше прямо до края экрана")
	info_label.text = "\n".join(lines)
	_paths.append({"points": _compute_path(pattern, PATTERN_SPEED), "color": COLOR_MAIN, "dashed": false, "age": 0.0})
	_paths.append({"points": _compute_path(pattern.mirrored(), PATTERN_SPEED), "color": COLOR_MIRROR, "dashed": true, "age": 0.0})


func _show_level() -> void:
	var c: int = _levels[_level_index][0]
	var l: int = _levels[_level_index][1]
	var chapter := GameState.get_chapter(c)
	var level: LevelData = chapter.levels[l]
	background.apply_chapter(chapter)
	title_label.text = "%s · %d. %s" % [chapter.planet, l + 1, level.title]

	var lines := PackedStringArray()
	for entry in level.timeline:
		if entry.wave:
			lines.append("%s  %s" % [_format_time(entry.time), entry.wave.title])
	if not level.filler_waves.is_empty():
		var names := PackedStringArray()
		for wave in level.filler_waves:
			names.append(wave.title)
		lines.append("с %s пачками по %d–%d, передышка %.1f–%.1f с, случайно: %s" % [_format_time(level.filler_from), level.group_min, level.group_max, level.rest_min, level.rest_max, ", ".join(names)])
	if not level.miniboss_at.is_empty():
		var at := PackedStringArray()
		for fraction in level.miniboss_at:
			at.append(_format_time(float(fraction) * level.duration))
		lines.append("мини-боссы: %s (в превью пропускаются)" % ", ".join(at))
	lines.append("%s  конец волн%s · здоровье врагов ×%.1f" % [_format_time(level.duration), " → БОСС %d HP" % level.boss_hp if level.boss else "", level.enemy_hp_mult])
	info_label.text = "\n".join(lines)
	director.start(level)


# --- Призраки и пути ----------------------------------------------------------

func _on_enemy_requested(wave: WaveData, pattern: FlightPattern) -> void:
	ghosts.spawn_for_wave(wave, pattern)


func _on_wave_started(wave: WaveData, _time: float) -> void:
	var info := ghosts.enemy_info(wave.enemy)
	var sides := [false, true] if wave.mirror == WaveData.Mirror.BOTH else [false]
	for mirrored in sides:
		_paths.append({"points": _compute_path(wave.pattern.mirrored() if mirrored else wave.pattern, info.speed), "color": COLOR_MAIN if not mirrored else COLOR_MIRROR, "dashed": mirrored, "age": 0.0})


## Путь траектории — та же симуляция, что у врага в игре.
func _compute_path(pattern: FlightPattern, speed: float) -> PackedVector2Array:
	var screen := get_viewport_rect()
	var motion := PatternMotion.new(pattern, speed, screen.size.x)
	var points := PackedVector2Array([motion.position])
	var seen := false
	var target := _player_spot()
	for i in int(30.0 / SIM_STEP):
		motion.advance(SIM_STEP, target)
		if i % 3 == 0:
			points.append(motion.position)
		if screen.has_point(motion.position):
			seen = true
		elif seen and not screen.grow(150.0).has_point(motion.position):
			break
	points.append(motion.position)
	return points


## Где обычно находится игрок — цель для манёвра «доворот на игрока».
func _player_spot() -> Vector2:
	var size := get_viewport_rect().size
	return Vector2(size.x / 2.0, size.y - 200.0)


# --- Рисование ----------------------------------------------------------------

func _draw_overlay() -> void:
	for path in _paths:
		var points: PackedVector2Array = path.points
		if points.size() < 2:
			continue
		var color: Color = path.color
		color.a = clampf(1.0 - path.age / TRAIL_LIFETIME, 0.15, 1.0) if mode == Mode.LEVELS else 1.0
		if path.dashed:
			for i in range(0, points.size() - 1, 2):
				overlay.draw_line(points[i], points[i + 1], color, 4.0)
		else:
			overlay.draw_polyline(points, color, 4.0, true)
		overlay.draw_circle(points[0], 10.0, color)
		_draw_arrow(points[points.size() - 2], points[points.size() - 1], color)

	# Условное место игрока (цель «охотников»).
	var spot := _player_spot()
	overlay.draw_arc(spot, 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0)
	overlay.draw_string(get_theme_default_font(), spot + Vector2(-34, 52), "игрок", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.7))

	if mode == Mode.LEVELS and director.level:
		_draw_timeline_bar()


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var dir := (to - from).normalized()
	if dir == Vector2.ZERO:
		return
	var side := dir.orthogonal() * 12.0
	overlay.draw_colored_polygon(PackedVector2Array([to + dir * 14.0, to - dir * 8.0 + side, to - dir * 8.0 - side]), color)


func _draw_timeline_bar() -> void:
	var size := get_viewport_rect().size
	var level := director.level
	var rect := Rect2(40, size.y - 190, size.x - 80, 14)
	overlay.draw_rect(rect, Color(0, 0, 0, 0.5))
	var t := clampf(director.time / level.duration, 0.0, 1.0)
	overlay.draw_rect(Rect2(rect.position, Vector2(rect.size.x * t, rect.size.y)), Color(1, 1, 1, 0.8))
	for entry in level.timeline:
		var x := rect.position.x + rect.size.x * clampf(entry.time / level.duration, 0.0, 1.0)
		overlay.draw_rect(Rect2(x - 2, rect.position.y - 8, 4, rect.size.y + 16), COLOR_MAIN)
	var filler_x := rect.position.x + rect.size.x * clampf(level.filler_from / level.duration, 0.0, 1.0)
	overlay.draw_rect(Rect2(filler_x - 1, rect.position.y - 4, 2, rect.size.y + 8), COLOR_MIRROR)


func _update_time_label() -> void:
	var level := director.level
	if level == null:
		return
	var state := ""
	if director.is_finished():
		state = " · волны закончились" + (" → босс" if level.boss else "")
	time_label.text = "%s / %s%s" % [_format_time(director.time), _format_time(level.duration), state]


# --- Тексты -------------------------------------------------------------------

func _describe_step(step: FlightStep) -> String:
	match step.type:
		FlightStep.Type.LINE:
			return "прямо %d px" % step.distance
		FlightStep.Type.TURN:
			var direction := "против часовой" if step.angle > 0 else "по часовой"
			return "поворот %d° %s, радиус %d" % [absf(step.angle), direction, step.radius]
		FlightStep.Type.AIM:
			return "доворот на игрока %.1f с (%d°/с)" % [step.duration, step.turn_rate]
		FlightStep.Type.HOVER:
			return "зависание %.1f с" % step.duration
		FlightStep.Type.PARK:
			return "остановиться и стоять"
	return "?"


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
