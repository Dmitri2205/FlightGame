class_name DataLibrary
extends RefCounted
## Библиотеки данных: все траектории (flight/patterns) и волны (flight/waves).

const PATTERNS_DIR := "res://flight/patterns"
const WAVES_DIR := "res://flight/waves"


static func patterns() -> Array[FlightPattern]:
	var result: Array[FlightPattern] = []
	for res in _load_dir(PATTERNS_DIR):
		if res is FlightPattern:
			result.append(res)
	return result


static func waves() -> Array[WaveData]:
	var result: Array[WaveData] = []
	for res in _load_dir(WAVES_DIR):
		if res is WaveData:
			result.append(res)
	return result


## В экспортированной игре ресурсы лежат как *.tres.remap — убираем суффикс.
static func _load_dir(dir: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres") and not name in names:
			names.append(name)
	names.sort()
	for name in names:
		var res := load("%s/%s" % [dir, name])
		if res:
			result.append(res)
	return result
