extends Node
## Переходы между экранами — в одном месте. Подключено как autoload `Router`.

const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const LEVEL_MAP := "res://ui/level_map/level_map.tscn"
const LEVEL := "res://level/level.tscn"
const UPGRADES := "res://ui/upgrade_menu/upgrade_menu.tscn"
const SHIPS := "res://ui/ship_select/ship_select.tscn"
const WAVE_PREVIEW := "res://ui/wave_preview/wave_preview.tscn"
const SETTINGS := "res://ui/settings/settings.tscn"


func main_menu() -> void:
	_go(MAIN_MENU)


func level_map() -> void:
	_go(LEVEL_MAP)


## Запустить уровень (по умолчанию — текущий выбранный в GameState).
func level(chapter := -1, level_index := -1) -> void:
	if chapter >= 0:
		GameState.select_level(chapter, level_index)
	_go(LEVEL)


func upgrades() -> void:
	_go(UPGRADES)


func ships() -> void:
	_go(SHIPS)


func wave_preview() -> void:
	_go(WAVE_PREVIEW)


func settings() -> void:
	_go(SETTINGS)


func reload() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go(path: String) -> void:
	get_tree().paused = false
	# Вне боя с боссом — основная тема.
	Music.play("assault")
	get_tree().change_scene_to_file(path)
