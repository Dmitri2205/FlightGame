class_name WaveDirector
extends Node
## Расписание волн уровня. Ничего не знает про очки, HUD и сцены врагов:
## по времени просит «выпусти врага такой-то волны по такой-то траектории»
## (сигнал enemy_requested). Им пользуются и уровень, и экран превью.
##
## Источники волн из LevelData:
## - timeline — волны в заданные секунды (авторский сценарий);
## - filler_waves — случайные волны каждые spawn_interval секунд,
##   начиная с filler_from и до конца уровня.

signal enemy_requested(wave: WaveData, pattern: FlightPattern, mirrored: bool)
## Волна только что вышла (для превью и отладки).
signal wave_started(wave: WaveData, time: float)

## Ускорение времени (превью умеет ×2, ×4).
var speed_scale := 1.0
## Наполнители по порядку, а не случайно (режим проверки всех волн).
var sequential_fillers := false

var level: LevelData
var time := 0.0
var running := false

## Запланированные враги: [{time, wave, pattern, mirrored}], по возрастанию time.
var _queue: Array[Dictionary] = []
var _timeline_index := 0
var _next_filler_time := 0.0
var _filler_index := 0
var _fillers: Array = []


func start(p_level: LevelData, fillers_override: Array = []) -> void:
	level = p_level
	time = 0.0
	running = true
	_queue.clear()
	_timeline_index = 0
	_filler_index = 0
	_fillers = fillers_override if not fillers_override.is_empty() else level.filler_waves
	_next_filler_time = level.filler_from


func stop() -> void:
	running = false
	_queue.clear()


## Время волн вышло и все запланированные враги уже выпущены.
func is_finished() -> bool:
	return time >= level.duration and _queue.is_empty() \
		and _timeline_index >= level.timeline.size()


## Сразу к концу уровня (тест босса).
func skip_to_end() -> void:
	time = level.duration
	_timeline_index = level.timeline.size()
	_queue.clear()


func _process(delta: float) -> void:
	if not running:
		return
	time += delta * speed_scale

	# Авторский таймлайн.
	while _timeline_index < level.timeline.size():
		var entry: TimelineEntry = level.timeline[_timeline_index]
		if entry.time > time:
			break
		_timeline_index += 1
		if entry.wave:
			_schedule(entry.wave, entry.time)

	# Наполнители.
	if not _fillers.is_empty() and time < level.duration:
		while time >= _next_filler_time and _next_filler_time < level.duration:
			_schedule(_pick_filler(), _next_filler_time)
			_next_filler_time += level.spawn_interval

	# Выпуск запланированных врагов.
	while not _queue.is_empty() and _queue[0].time <= time:
		var item: Dictionary = _queue.pop_front()
		enemy_requested.emit(item.wave, item.pattern, item.mirrored)


func _pick_filler() -> WaveData:
	if sequential_fillers:
		var wave: WaveData = _fillers[_filler_index % _fillers.size()]
		_filler_index += 1
		return wave
	return _fillers.pick_random()


## Раскладывает волну на отдельных врагов с интервалом.
func _schedule(wave: WaveData, at: float) -> void:
	if wave.pattern == null or wave.enemy == null:
		push_warning("Волна «%s» без врага или траектории" % wave.title)
		return
	var pattern := wave.pattern
	if wave.random_x:
		pattern = pattern.duplicate()
		pattern.start.x = randf_range(0.15, 0.85)
	wave_started.emit(wave, at)

	var sides: Array[bool] = []
	match wave.mirror:
		WaveData.Mirror.BOTH:
			sides = [false, true]
		WaveData.Mirror.RANDOM:
			sides = [randf() < 0.5]
		_:
			sides = [false]
	for mirrored in sides:
		for i in wave.count:
			_queue.append({"time": at + wave.interval * i, "wave": wave, "pattern": pattern, "mirrored": mirrored})
	_queue.sort_custom(func(a, b): return a.time < b.time)
