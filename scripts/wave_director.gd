class_name WaveDirector
extends Node
## Расписание волн уровня. Ничего не знает про очки, HUD и сцены врагов:
## по времени просит «выпусти врага такой-то волны по такой-то траектории»
## (сигнал enemy_requested). Им пользуются и уровень, и экран превью.
##
## Источники волн из LevelData:
## - timeline — волны в заданные секунды (авторский сценарий);
## - filler_waves — случайные волны с filler_from до конца уровня, пачками:
##   1–3 воздушные волны друг за другом, потом передышка, в которую может
##   выехать наземная волна (параметры — группа «Темп» в LevelData);
## - miniboss_at — мини-боссы: сигнал miniboss_requested, и время стоит,
##   пока уровень не вызовет resume() (мини-босс сбит).

signal enemy_requested(wave: WaveData, pattern: FlightPattern, mirrored: bool)
## Волна только что вышла (для превью и отладки).
signal wave_started(wave: WaveData, time: float)
## Пора выпускать мини-босса номер index. Если сигнал никто не слушает
## (превью, меню), мини-босс просто пропускается.
signal miniboss_requested(index: int)

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
var _air: Array = []
var _ground: Array = []
var _ground_index := 0
var _miniboss_index := 0
## Время стоит (идёт бой с мини-боссом).
var _held := false


func start(p_level: LevelData, fillers_override: Array = []) -> void:
	level = p_level
	time = 0.0
	running = true
	_queue.clear()
	_timeline_index = 0
	_filler_index = 0
	_ground_index = 0
	_miniboss_index = 0
	_held = false
	var fillers: Array = fillers_override if not fillers_override.is_empty() else level.filler_waves
	_air.clear()
	_ground.clear()
	for wave in fillers:
		if wave is WaveData:
			(_ground if wave.is_ground() else _air).append(wave)
	# Только наземные — пусть идут как обычные пачки.
	if _air.is_empty():
		_air = _ground.duplicate()
		_ground.clear()
	_next_filler_time = level.filler_from


func stop() -> void:
	running = false
	_queue.clear()


## Время волн вышло и все запланированные враги уже выпущены.
func is_finished() -> bool:
	return time >= level.duration and _queue.is_empty() and not _held \
		and _timeline_index >= level.timeline.size()


## Сразу к концу уровня (тест босса).
func skip_to_end() -> void:
	time = level.duration
	_timeline_index = level.timeline.size()
	_miniboss_index = level.miniboss_at.size()
	_held = false
	_queue.clear()


## Мини-босс сбит — время уровня снова идёт.
func resume() -> void:
	_held = false


func is_held() -> bool:
	return _held


func _process(delta: float) -> void:
	if not running or _held:
		return
	time += delta * speed_scale

	# Мини-боссы.
	if _miniboss_index < level.miniboss_at.size() \
			and time >= float(level.miniboss_at[_miniboss_index]) * level.duration:
		var index := _miniboss_index
		_miniboss_index += 1
		if not miniboss_requested.get_connections().is_empty():
			time = float(level.miniboss_at[index]) * level.duration
			_held = true
			miniboss_requested.emit(index)
			return

	# Авторский таймлайн.
	while _timeline_index < level.timeline.size():
		var entry: TimelineEntry = level.timeline[_timeline_index]
		if entry.time > time:
			break
		_timeline_index += 1
		if entry.wave:
			_schedule(entry.wave, entry.time)

	# Наполнители — пачками с передышками.
	if not _air.is_empty() and time < level.duration:
		while time >= _next_filler_time and _next_filler_time < level.duration:
			_next_filler_time = _schedule_group(_next_filler_time)

	# Выпуск запланированных врагов.
	while not _queue.is_empty() and _queue[0].time <= time:
		var item: Dictionary = _queue.pop_front()
		enemy_requested.emit(item.wave, item.pattern, item.mirrored)


## Пачка: 1–3 воздушные волны друг за другом, потом передышка (может
## выехать наземная волна). Возвращает время начала следующей пачки.
func _schedule_group(at: float) -> float:
	var t := at
	var count := randi_range(level.group_min, maxi(level.group_min, level.group_max))
	for i in count:
		var wave := _pick(_air, false)
		_schedule(wave, t)
		t += wave.duration() + level.wave_gap
	var rest := randf_range(level.rest_min, maxf(level.rest_min, level.rest_max))
	if not _ground.is_empty() and randf() < level.ground_chance:
		_schedule(_pick(_ground, true), t + rest * 0.25)
	return t + rest


func _pick(pool: Array, ground: bool) -> WaveData:
	if sequential_fillers:
		var index := _ground_index if ground else _filler_index
		var wave: WaveData = pool[index % pool.size()]
		if ground:
			_ground_index += 1
		else:
			_filler_index += 1
		return wave
	return pool.pick_random()


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
	var interval := wave.spawn_interval()
	for mirrored in sides:
		for i in wave.count:
			_queue.append({"time": at + interval * i, "wave": wave, "pattern": pattern, "mirrored": mirrored})
	_queue.sort_custom(func(a, b): return a.time < b.time)
