extends Node2D
## Уровень: собирает вместе игрока, WaveDirector (расписание волн), HUD,
## счёт и босса. Сами волны описаны в данных — LevelData текущего уровня
## (GameState.current_level_data()), см. экран «Превью волн».
##
## Отладка:
## - сразу к боссу — GameState.boss_test или аргумент `-- --boss`;
## - все волны по очереди — GameState.pattern_test или `-- --patterns`;
## - конкретный уровень — аргумент `-- --level=глава:уровень` (с нуля).

@export var star_scene: PackedScene
@export var boss_scene: PackedScene
## Пауза после победы над боссом, чтобы успеть собрать звёзды.
@export var victory_delay := 3.0

var score := 0
var run_stars := 0
var level_data: LevelData

var _finished := false
var _boss_spawned := false
var _force_boss := false

@onready var player = $Player
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var hud = $HUD
@onready var director: WaveDirector = $WaveDirector


func _ready() -> void:
	_apply_cli_level()
	level_data = GameState.current_level_data()

	player.place_at(Vector2(get_viewport_rect().size.x / 2.0, get_viewport_rect().size.y - 200.0))
	player.projectile_container = projectiles
	player.health_changed.connect(hud.set_health)
	player.died.connect(_finish.bind(false))
	hud.menu_requested.connect(_go_to_map)
	hud.retry_requested.connect(Router.reload)
	hud.next_requested.connect(_next_level)
	director.enemy_requested.connect(_spawn_enemy)

	hud.set_health(player.health, player.max_health)
	hud.set_score(score)
	hud.set_stars(run_stars)
	var chapter := GameState.current_chapter_data()
	hud.show_banner("%s · %d. %s" % [chapter.planet, GameState.current_level + 1, level_data.title])

	if GameState.pattern_test or "--patterns" in OS.get_cmdline_user_args():
		GameState.pattern_test = false
		director.sequential_fillers = true
		director.start(level_data, DataLibrary.waves())
	else:
		director.start(level_data)

	if GameState.boss_test or "--boss" in OS.get_cmdline_user_args():
		GameState.boss_test = false
		director.skip_to_end()
		_force_boss = true


func _process(_delta: float) -> void:
	if _finished:
		return
	hud.set_progress(director.time / level_data.duration)
	# Сначала добиваем оставшиеся волны, потом выходит босс.
	if director.is_finished() and not _boss_spawned and enemies.get_child_count() == 0:
		if boss_scene and (level_data.boss or _force_boss):
			_spawn_boss()
		else:
			_finish(true)


## Свернули браузер/приложение или нажали «назад» на Android — ставим на паузу.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST:
			if not _finished and is_node_ready():
				hud.pause()


func _apply_cli_level() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			var parts := arg.trim_prefix("--level=").split(":")
			GameState.select_level(int(parts[0]), int(parts[1]) if parts.size() > 1 else 0)


# --- Враги и босс -------------------------------------------------------------

func _spawn_enemy(wave: WaveData, pattern: FlightPattern, mirrored: bool) -> void:
	if _finished:
		return
	var enemy = wave.enemy.instantiate()
	enemy.pattern = pattern
	enemy.mirrored = mirrored
	enemy.max_hp = ceili(enemy.max_hp * level_data.enemy_hp_mult)
	enemy.position = pattern.start_position(get_viewport_rect().size.x, mirrored)
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
	get_tree().create_timer(victory_delay, false).timeout.connect(_finish.bind(true))


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
	director.stop()
	GameState.add_stars(run_stars)
	var bonus := GameState.complete_current_level(score) if victory else 0
	hud.show_results(victory, score, run_stars, bonus, victory and GameState.has_next_level())


func _go_to_map() -> void:
	if not _finished:
		_finish(false)
	Router.level_map()


func _next_level() -> void:
	GameState.select_next_level()
	Router.reload()
