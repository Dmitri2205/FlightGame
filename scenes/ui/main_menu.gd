extends Control


func _ready() -> void:
	%StarsLabel.text = "%d" % GameState.stars
	%PlayButton.pressed.connect(Router.level_map)
	%ShipsButton.text = "Корабль: %s" % GameState.get_selected_ship().title
	%ShipsButton.pressed.connect(Router.ships)
	%BossTestButton.pressed.connect(_start_boss_test)
	%PatternTestButton.pressed.connect(_start_pattern_test)
	%UpgradesButton.pressed.connect(Router.upgrades)
	%PreviewButton.pressed.connect(Router.wave_preview)


func _start_boss_test() -> void:
	GameState.boss_test = true
	Router.level()


func _start_pattern_test() -> void:
	GameState.pattern_test = true
	Router.level()
