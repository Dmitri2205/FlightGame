extends SceneTree
## Проверка данных: все главы, уровни, волны и траектории ссылаются на
## существующее и заполнены. Запуск (CI):
##   godot --headless --path . --script res://tests/validate_data.gd
## При ошибках печатает «ERROR: …» и выходит с кодом 1.

var _errors := 0


func _init() -> void:
	for path in ["res://data/patterns", "res://data/waves"]:
		if DirAccess.get_files_at(path).is_empty():
			_fail("пустая папка %s" % path)
	for pattern in DataLibrary.patterns():
		_check_pattern(pattern)
	for wave in DataLibrary.waves():
		_check_wave(wave)

	for chapter_path in load("res://scripts/game_state.gd").CHAPTER_PATHS:
		var chapter := load(chapter_path) as ChapterData
		if chapter == null:
			_fail("не загружается глава %s" % chapter_path)
			continue
		if chapter.levels.is_empty():
			_fail("%s: нет уровней" % chapter.id)
		for i in chapter.levels.size():
			_check_level(chapter, i)

	print("validate_data: %s" % ("OK" if _errors == 0 else "%d ошибок" % _errors))
	quit(1 if _errors > 0 else 0)


func _check_pattern(pattern: FlightPattern) -> void:
	for step in pattern.steps:
		if not step is FlightStep:
			_fail("%s: манёвр не FlightStep" % pattern.resource_path)
		elif step.type == FlightStep.Type.TURN and step.radius <= 0.0:
			_fail("%s: поворот с радиусом <= 0" % pattern.resource_path)


func _check_wave(wave: WaveData) -> void:
	if wave.enemy == null:
		_fail("%s: не задан враг" % wave.resource_path)
	if wave.pattern == null:
		_fail("%s: не задана траектория" % wave.resource_path)
	if wave.count < 1:
		_fail("%s: count < 1" % wave.resource_path)


func _check_level(chapter: ChapterData, index: int) -> void:
	var level := chapter.levels[index] as LevelData
	var where := "%s, уровень %d" % [chapter.id, index + 1]
	if level == null:
		_fail("%s: не LevelData" % where)
		return
	if level.timeline.is_empty() and level.filler_waves.is_empty():
		_fail("%s: нет ни таймлайна, ни наполнителей" % where)
	var last := -1.0
	for entry in level.timeline:
		if not entry is TimelineEntry or entry.wave == null:
			_fail("%s: пустая строка таймлайна" % where)
			continue
		if entry.time < last:
			_fail("%s: таймлайн не по возрастанию времени (%.1f после %.1f)" % [where, entry.time, last])
		if entry.time > level.duration:
			_fail("%s: волна на %.1f с позже конца уровня (%.1f с)" % [where, entry.time, level.duration])
		last = entry.time
	for wave in level.filler_waves:
		if not wave is WaveData:
			_fail("%s: наполнитель не WaveData" % where)
	if not level.filler_waves.is_empty() and level.spawn_interval <= 0.0:
		_fail("%s: spawn_interval <= 0" % where)


func _fail(message: String) -> void:
	_errors += 1
	push_error(message)
	printerr("ERROR: " + message)
