extends Control


func _ready() -> void:
	%StarsLabel.text = "%d" % GameState.stars
	%PlayButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/level.tscn"))
	%ShipsButton.text = "Корабль: %s" % GameState.get_selected_ship().title
	%ShipsButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/ship_select.tscn"))
	%BossTestButton.pressed.connect(_start_boss_test)
	%UpgradesButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/upgrade_menu.tscn"))


func _start_boss_test() -> void:
	GameState.boss_test = true
	get_tree().change_scene_to_file("res://scenes/game/level.tscn")
