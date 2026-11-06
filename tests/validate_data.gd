extends Node
## Проверка данных: все главы, уровни, волны, траектории и корабли ссылаются на
## существующее и заполнены. Запуск (CI):
##   godot --headless --path . res://tests/validate_data.tscn
## Это сцена, а не --script: так подключаются autoload (FX, GameState…),
## без которых не компилируются скрипты врагов, на которые ссылаются волны.
## При ошибках печатает «ERROR: …» и выходит с кодом 1.

var _errors := 0


## Где лежат сцены врагов (проверяются все *.tscn, включая подпапки).
const ENEMIES_DIR := "res://enemies"
## Сцена разрушаемой постройки (списки видов PropKind).
const PROP_SCENE := "res://level/destructible.tscn"


func _ready() -> void:
	for path in [DataLibrary.PATTERNS_DIR, DataLibrary.WAVES_DIR]:
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

	_check_ships()
	var enemy_scenes := _scenes_in(ENEMIES_DIR)
	if enemy_scenes.is_empty():
		_fail("нет сцен врагов в %s" % ENEMIES_DIR)
	for path in enemy_scenes:
		_check_enemy_scene(path)
	_check_props()

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
	elif not _is_wave_enemy(wave.enemy):
		_fail("%s: враг волны должен быть WaveEnemy (AirEnemy или GroundUnit)" % wave.resource_path)
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
	if chapter.enemy_hp_multiplier(index) <= 0.0:
		_fail("%s: множитель здоровья врагов должен быть > 0" % where)
	if not level.miniboss_at.is_empty() and chapter.miniboss_hp(index) <= 0:
		_fail("%s: здоровье мини-босса должно быть > 0" % where)


func _check_ships() -> void:
	var first := ShipCatalog.first()
	if first.cost != 0 or first.blueprints_required != 0:
		_fail("%s: первый корабль должен быть доступен сразу" % first.id)
	var seen := {}
	for ship in ShipCatalog.all():
		if ship.id == "" or seen.has(ship.id):
			_fail("%s: пустой или повторяющийся id корабля" % ship.resource_path)
		seen[ship.id] = true
		if ship.texture == null:
			_fail("%s: не задан спрайт" % ship.id)
		if not View3D.has_model(ship.model_3d):
			_fail("%s: model_3d «%s» — нет такой 3D-модели" % [ship.id, ship.model_3d])


func _is_wave_enemy(scene: PackedScene) -> bool:
	var node := scene.instantiate()
	var result := node is WaveEnemy
	node.free()
	return result


## Каждая сцена врага: корень — EnemyBase с 3D-моделью, награда, пушка заполнена.
func _check_enemy_scene(path: String) -> void:
	var node := (load(path) as PackedScene).instantiate()
	var enemy := node as EnemyBase
	if enemy == null:
		_fail("%s: корень сцены врага должен быть EnemyBase" % path)
		node.free()
		return
	if not View3D.has_model(enemy.model_3d):
		_fail("%s: model_3d «%s» — нет такой 3D-модели" % [path, enemy.model_3d])
	if enemy.score_value <= 0 or enemy.star_drop < 0:
		_fail("%s: награда: нужно score_value > 0, star_drop >= 0" % path)
	if enemy.gun:
		_check_gun(path, enemy.gun)
	var wave_enemy := enemy as WaveEnemy
	if wave_enemy:
		if wave_enemy.max_hp <= 0:
			_fail("%s: max_hp должен быть > 0" % path)
		if wave_enemy.fire_interval > 0.0 and wave_enemy.gun == null:
			_fail("%s: fire_interval > 0, но нет пушки (gun)" % path)
	elif enemy is Boss:
		if enemy.gun == null:
			_fail("%s: у босса нет пушки (gun)" % path)
	else:
		_fail("%s: неизвестный тип врага — ни WaveEnemy, ни Boss" % path)
	node.free()


func _check_gun(where: String, gun: GunData) -> void:
	if gun.bullet_scene == null:
		_fail("%s: у пушки не задана сцена пули" % where)
	if gun.bullet_speed <= 0.0 or gun.bullet_damage <= 0:
		_fail("%s: у пушки нужны bullet_speed > 0 и bullet_damage > 0" % where)


## Виды построек: заполнены и у каждого есть 3D-модель.
func _check_props() -> void:
	var prop := (load(PROP_SCENE) as PackedScene).instantiate() as Destructible
	if prop == null:
		_fail("%s: корень должен быть Destructible" % PROP_SCENE)
		return
	if prop.small_kinds.is_empty() or prop.large_kinds.is_empty():
		_fail("%s: пустой список мелких или крупных построек" % PROP_SCENE)
	for kind in prop.small_kinds + prop.large_kinds:
		if kind == null:
			_fail("%s: пустой элемент в списке построек" % PROP_SCENE)
			continue
		if kind.texture == null:
			_fail("%s: не задан спрайт" % kind.resource_path)
		if kind.hp <= 0 or kind.stars < 0:
			_fail("%s: нужно hp > 0, stars >= 0" % kind.resource_path)
		if not View3D.has_model(kind.model_3d):
			_fail("%s: model_3d «%s» — нет такой 3D-модели" % [kind.resource_path, kind.model_3d])
	prop.free()


## Все *.tscn в папке и подпапках.
func _scenes_in(dir: String) -> PackedStringArray:
	var result := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		var file_name := file.trim_suffix(".remap")
		if file_name.ends_with(".tscn") and not "%s/%s" % [dir, file_name] in result:
			result.append("%s/%s" % [dir, file_name])
	for sub in DirAccess.get_directories_at(dir):
		result.append_array(_scenes_in("%s/%s" % [dir, sub]))
	return result


func _fail(message: String) -> void:
	_errors += 1
	push_error(message)
	printerr("ERROR: " + message)
