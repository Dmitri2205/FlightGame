extends Control


func _ready() -> void:
	%StarsLabel.text = "★ %d" % GameState.stars
	%PlayButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/level.tscn"))
	%UpgradesButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/upgrade_menu.tscn"))
