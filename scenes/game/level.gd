extends Node2D
## Уровень: спавнит волны врагов, в конце — босс. Считает очки и звёзды,
## по окончании начисляет звёзды в GameState.
## Сразу к боссу: GameState.boss_test = true (кнопка в меню)
## или аргумент `-- --boss` при запуске из командной строки.

@export var enemy_scenes: Array[PackedScene] = []
@export var star_scene: PackedScene
@export var level_duration := 60.0
@export var boss_scene: PackedScene
## Пауза после победы над боссом, чтобы успеть собрать звёзды.
@export var victory_delay := 3.0

var score := 0
var run_stars := 0
var elapsed := 0.0

var _finished := false
var _boss_spawned := false

@onready var player = $Player
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var hud = $HUD
@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	player.place_at(Vector2(get_viewport_rect().size.x / 2.0, get_viewport_rect().size.y - 200.0))
	player.projectile_container = projectiles
	player.health_changed.connect(hud.set_health)
	player.died.connect(_finish.bind(false))
	spawn_timer.timeout.connect(_spawn_wave)
	hud.menu_requested.connect(_go_to_menu)

	hud.set_health(player.health, player.max_health)
	hud.set_score(score)
	hud.set_stars(run_stars)

	if GameState.boss_test or "--boss" in OS.get_cmdline_user_args():
		GameState.boss_test = false
		elapsed = level_duration
		spawn_timer.stop()


func _process(delta: float) -> void:
	if _finished:
		return
	elapsed += delta
	hud.set_progress(elapsed / level_duration)
	if elapsed >= level_duration:
		spawn_timer.stop()
		# Сначала добиваем оставшиеся волны, потом выходит босс.
		if not _boss_spawned and enemies.get_child_count() == 0:
			if boss_scene:
				_spawn_boss()
			else:
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


func _spawn_boss() -> void:
	_boss_spawned = true
	var boss = boss_scene.instantiate()
	boss.position = Vector2(get_viewport_rect().size.x / 2.0, -150.0)
	boss.projectile_container = projectiles
	boss.destroyed.connect(_on_enemy_destroyed)
	boss.destroyed.connect(_on_boss_destroyed)
	boss.health_changed.connect(hud.set_boss_health)
	enemies.add_child(boss)
	hud.show_boss(boss.max_hp)


func _on_boss_destroyed(_boss) -> void:
	hud.hide_boss()
	get_tree().create_timer(victory_delay).timeout.connect(_finish.bind(true))


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

	if GameState.boss_test or "--boss" in OS.get_cmdline_user_args():
		GameState.boss_test = false
		elapsed = level_duration
		spawn_timer.stop()


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
