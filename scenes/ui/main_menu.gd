extends Control


func _ready() -> void:
	%StarsLabel.text = "★ %d" % GameState.stars
	%PlayButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/level.tscn"))
	%ShipsButton.text = "Корабль: %s" % GameState.get_selected_ship().title
	%ShipsButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/ship_select.tscn"))
	%UpgradesButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/upgrade_menu.tscn"))
