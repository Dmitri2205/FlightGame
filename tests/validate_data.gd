extends Node
## Проверка данных: все главы, уровни, волны и траектории ссылаются на
## существующее и заполнены. Запуск (CI):
##   godot --headless --path . res://tests/validate_data.tscn
## Это сцена, а не --script: так подключаются autoload (FX, GameState…),
## без которых не компилируются скрипты врагов, на которые ссылаются волны.
## При ошибках печатает «ERROR: …» и выходит с кодом 1.

var _errors := 0


func _ready() -> void:
	for path in ["res://data/patterns", "res://data/waves"]:
		if DirAccess.get_files_at(path).is_empty():
			_fail("пустая папка %s" % path)
	for pattern in DataLibrary.patterns():
		_check_pattern(pattern)
	for wave in DataLibrary.waves():
		_check_wave(wave)

	for chapter in ChapterCatalog.all():
		if chapter.levels.is_empty():
			_fail("%s: нет уровней" % chapter.id)
		for i in chapter.levels.size():
			_check_level(chapter, i)

	print("validate_data: %s" % ("OK" if _errors == 0 else "%d ошибок" % _errors))
	get_tree().quit(1 if _errors > 0 else 0)


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
	if wave.count > 1 and wave.spacing <= 0.0:
		_fail("%s: spacing <= 0 — враги «паровозика» слипнутся" % wave.resource_path)


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
	if level.group_min < 1 or level.group_max < level.group_min:
		_fail("%s: пачка волн: нужно 1 <= group_min <= group_max" % where)
	if level.rest_min <= 0.0 or level.rest_max < level.rest_min:
		_fail("%s: передышка: нужно 0 < rest_min <= rest_max" % where)
	var last_miniboss := 0.0
	for fraction in level.miniboss_at:
		if float(fraction) <= last_miniboss or float(fraction) >= 1.0:
			_fail("%s: miniboss_at — доли от 0 до 1 по возрастанию" % where)
		last_miniboss = float(fraction)


func _fail(message: String) -> void:
	_errors += 1
	push_error(message)
	printerr("ERROR: " + message)
