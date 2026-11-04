extends Node2D
## Уровень: спавнит волны врагов, в конце — босс (если он есть у уровня).
## Параметры берутся из GameState.current_level_data() (глава → LevelData).
## Считает очки и звёзды, по окончании записывает прогресс в GameState.
## Сразу к боссу: GameState.boss_test = true (кнопка в меню)
## или аргумент `-- --boss` при запуске из командной строки.
## Все волны по очереди: GameState.pattern_test = true или `-- --patterns`.

@export var enemy_scenes: Array[PackedScene] = []
@export var star_scene: PackedScene
## Волны: траектория (FlightPatterns), тип врага (индекс в enemy_scenes),
## сколько врагов в «паровозике», интервал между ними (с) и зеркалирование:
## "none" — как описано, "random" — случайная сторона, "both" — пара с двух сторон.
## random_x — случайная точка появления по горизонтали.
## Ключи — то, что перечисляется в LevelData.waves.
const WAVES := {
	"diagonal": {"pattern": "diagonal", "enemy": 0, "count": 5, "interval": 0.25, "mirror": "random"},
	"loop": {"pattern": "loop", "enemy": 0, "count": 4, "interval": 0.3, "mirror": "random"},
	"swoop": {"pattern": "swoop", "enemy": 0, "count": 4, "interval": 0.25, "mirror": "both"},
	"side_sweep": {"pattern": "side_sweep", "enemy": 0, "count": 5, "interval": 0.3, "mirror": "random"},
	"zigzag": {"pattern": "zigzag", "enemy": 0, "count": 3, "interval": 0.45, "mirror": "random"},
	"s_curve": {"pattern": "s_curve", "enemy": 0, "count": 6, "interval": 0.2, "mirror": "random"},
	"hunter": {"pattern": "hunter", "enemy": 0, "count": 2, "interval": 0.6, "mirror": "both"},
	"dive": {"pattern": "dive", "enemy": 0, "count": 4, "interval": 0.35, "mirror": "none", "random_x": true},
	"drift": {"pattern": "drift", "enemy": 1, "count": 1, "interval": 0.0, "mirror": "none", "random_x": true},
}
@export var boss_scene: PackedScene
## Пауза после победы над боссом, чтобы успеть собрать звёзды.
@export var victory_delay := 3.0

var score := 0
var level_data: LevelData
var level_duration := 60.0
var run_stars := 0
var elapsed := 0.0

var _finished := false
var _boss_spawned := false
## Режим проверки траекторий: волны идут по порядку, а не случайно.
var _pattern_test := false
var _next_wave := 0
var _wave_ids: Array = []
var _force_boss := false

@onready var player = $Player
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var hud = $HUD
@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
	level_data = GameState.current_level_data()
	level_duration = level_data.duration
	spawn_timer.wait_time = level_data.spawn_interval
	_wave_ids = Array(level_data.waves).filter(func(id): return WAVES.has(id))
	if _wave_ids.is_empty():
		_wave_ids = WAVES.keys()

	player.place_at(Vector2(get_viewport_rect().size.x / 2.0, get_viewport_rect().size.y - 200.0))
	player.projectile_container = projectiles
	player.health_changed.connect(hud.set_health)
	player.died.connect(_finish.bind(false))
	spawn_timer.timeout.connect(_spawn_wave)
	hud.menu_requested.connect(_go_to_map)
	hud.retry_requested.connect(_retry)
	hud.next_requested.connect(_next_level)

	hud.set_health(player.health, player.max_health)
	hud.set_score(score)
	hud.set_stars(run_stars)
	var chapter := GameState.current_chapter_data()
	hud.show_banner("%s · %d. %s" % [chapter.planet, GameState.current_level + 1, level_data.title])

	if GameState.boss_test or "--boss" in OS.get_cmdline_user_args():
		GameState.boss_test = false
		elapsed = level_duration
		spawn_timer.stop()
		_force_boss = true
	elif GameState.pattern_test or "--patterns" in OS.get_cmdline_user_args():
		GameState.pattern_test = false
		_pattern_test = true
		_wave_ids = WAVES.keys()


func _process(delta: float) -> void:
	if _finished:
		return
	elapsed += delta
	hud.set_progress(elapsed / level_duration)
	if elapsed >= level_duration:
		spawn_timer.stop()
		# Сначала добиваем оставшиеся волны, потом выходит босс.
		if not _boss_spawned and enemies.get_child_count() == 0:
			if boss_scene and (level_data.boss or _force_boss):
				_spawn_boss()
			else:
				_finish(true)


# --- Волны --------------------------------------------------------------------

func _spawn_wave() -> void:
	if enemy_scenes.is_empty():
		return
	var wave: Dictionary
	if _pattern_test:
		wave = WAVES[_wave_ids[_next_wave % _wave_ids.size()]]
		_next_wave += 1
	else:
		wave = WAVES[_wave_ids.pick_random()]

	var pattern := FlightPatterns.get_pattern(wave.pattern)
	if wave.get("random_x", false):
		pattern.start = Vector2(randf_range(0.15, 0.85), pattern.start.y)
	var scene: PackedScene = enemy_scenes[mini(wave.enemy, enemy_scenes.size() - 1)]

	var sides: Array[bool] = []
	match wave.mirror:
		"both":
			sides = [false, true]
		"random":
			sides = [randf() < 0.5]
		_:
			sides = [false]
	for mirrored in sides:
		for i in wave.count:
			if i == 0:
				_spawn_enemy(scene, pattern, mirrored)
			else:
				get_tree().create_timer(wave.interval * i, false).timeout.connect(
					_spawn_enemy.bind(scene, pattern, mirrored))


func _spawn_enemy(scene: PackedScene, pattern: Dictionary, mirrored: bool) -> void:
	if _finished:
		return
	var enemy = scene.instantiate()
	enemy.pattern = pattern
	enemy.mirrored = mirrored
	enemy.max_hp = ceili(enemy.max_hp * level_data.enemy_hp_mult)
	enemy.position = FlightPatterns.start_position(pattern, get_viewport_rect().size.x, mirrored)
	enemy.projectile_container = projectiles
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemies.add_child(enemy)


func _spawn_boss() -> void:
	_boss_spawned = true
	var boss = boss_scene.instantiate()
	boss.max_hp = level_data.boss_hp
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


# --- Конец уровня -------------------------------------------------------------

func _finish(victory: bool) -> void:
	if _finished:
		return
	_finished = true
	spawn_timer.stop()
	GameState.add_stars(run_stars)
	var bonus := GameState.complete_current_level(score) if victory else 0
	hud.show_results(victory, score, run_stars, bonus, victory and GameState.has_next_level())


func _go_to_map() -> void:
	if not _finished:
		_finish(false)
	get_tree().change_scene_to_file("res://scenes/ui/level_map.tscn")


func _retry() -> void:
	get_tree().reload_current_scene()


func _next_level() -> void:
	GameState.select_next_level()
	get_tree().reload_current_scene()
