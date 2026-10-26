extends Node2D
## Уровень: спавнит волны врагов, считает очки и звёзды,
## по окончании начисляет звёзды в GameState.

@export var enemy_scenes: Array[PackedScene] = []
@export var star_scene: PackedScene
@export var level_duration := 60.0

var score := 0
var run_stars := 0
var elapsed := 0.0

var _finished := false

@onready var player = $Player
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var hud = $HUD
@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	player.position = Vector2(get_viewport_rect().size.x / 2.0, get_viewport_rect().size.y - 200.0)
	player.projectile_container = projectiles
	player.health_changed.connect(hud.set_health)
	player.died.connect(_finish.bind(false))
	spawn_timer.timeout.connect(_spawn_wave)
	hud.menu_requested.connect(_go_to_menu)

	hud.set_health(player.health, player.max_health)
	hud.set_score(score)
	hud.set_stars(run_stars)


func _process(delta: float) -> void:
	if _finished:
		return
	elapsed += delta
	hud.set_progress(elapsed / level_duration)
	if elapsed >= level_duration:
		spawn_timer.stop()
		if enemies.get_child_count() == 0:
			_finish(true)


# --- Волны --------------------------------------------------------------------

func _spawn_wave() -> void:
	if enemy_scenes.is_empty():
		return
	var width := get_viewport_rect().size.x
	match randi() % 3:
		0:  # одиночный враг (иногда тяжёлый)
			_spawn_enemy(enemy_scenes.pick_random(), Vector2(randf_range(80.0, width - 80.0), -60.0))
		1:  # линия
			var count := randi_range(3, 5)
			for i in count:
				var x := width * (i + 1) / (count + 1)
				_spawn_enemy(enemy_scenes[0], Vector2(x, -60.0))
		2:  # клин
			var center := randf_range(200.0, width - 200.0)
			for i in 5:
				var offset := i - 2
				_spawn_enemy(enemy_scenes[0], Vector2(center + offset * 70.0, -60.0 - absi(offset) * 60.0))


func _spawn_enemy(scene: PackedScene, pos: Vector2) -> void:
	var enemy = scene.instantiate()
	enemy.position = pos
	enemy.projectile_container = projectiles
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemies.add_child(enemy)


func _on_enemy_destroyed(enemy) -> void:
	score += enemy.score_value
	hud.set_score(score)
	if star_scene == null:
		return
	for i in enemy.star_drop:
		var star = star_scene.instantiate()
		star.position = enemy.position
		star.collected.connect(_on_star_collected)
		# Нельзя добавлять Area2D прямо во время обработки коллизий.
		pickups.add_child.call_deferred(star)


func _on_star_collected() -> void:
	run_stars += 1
	hud.set_stars(run_stars)


# --- Конец уровня -------------------------------------------------------------

func _finish(victory: bool) -> void:
	if _finished:
		return
	_finished = true
	spawn_timer.stop()
	GameState.add_stars(run_stars)
	hud.show_results(victory, score, run_stars)


func _go_to_menu() -> void:
	if not _finished:
		_finish(false)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
