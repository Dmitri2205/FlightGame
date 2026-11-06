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
## Мини-босс посреди уровня (LevelData.miniboss_at).
@export var miniboss_scene: PackedScene
## Разрушаемые объекты на земле и выпадающий из них чертёж.
@export var prop_scene: PackedScene
@export var blueprint_scene: PackedScene
## Мир шире экрана: камера плавно едет за игроком влево-вправо (как в
## Sky Force), по бокам остаётся запас. Ширина мира, px.
@export var world_width := 900.0
## Насколько быстро камера догоняет игрока по горизонтали.
@export var camera_follow := 4.0
## Пауза между группами разрушаемых объектов, секунд.
@export var prop_interval_min := 5.0
@export var prop_interval_max := 9.0
## Пауза после победы над боссом, чтобы успеть собрать звёзды.
@export var victory_delay := 3.0

var score := 0
var run_stars := 0
var run_crystals := 0
var level_data: LevelData

var _finished := false
var _boss_spawned := false
var _force_boss := false
var _prop_cooldown := 2.0
## Чертёж какого корабля спрятан на этом заходе ("" — нет) и найден ли он.
var _hidden_blueprint := ""
var _blueprint_dropped := false
var _found_blueprint := ""

@onready var player = $Player
@onready var projectiles: Node2D = $Projectiles
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var props: Node2D = $Props
@onready var hud = $HUD
@onready var director: WaveDirector = $WaveDirector


func _ready() -> void:
	Arena.world_width = world_width
	tree_exiting.connect(func() -> void: Arena.world_width = 0.0)
	_apply_cli_level()
	level_data = GameState.current_level_data()

	player.place_at(Vector2(Arena.rect().size.x / 2.0, Arena.rect().size.y - 200.0))
	$Camera.position.x = maxf(Arena.rect().size.x - Arena.visible_size().x, 0.0) / 2.0
	player.projectile_container = projectiles
	player.health_changed.connect(hud.set_health)
	player.died.connect(_finish.bind(false))
	hud.menu_requested.connect(_go_to_map)
	hud.retry_requested.connect(Router.reload)
	hud.next_requested.connect(_next_level)
	director.enemy_requested.connect(_spawn_enemy)
	director.miniboss_requested.connect(_spawn_miniboss)
	Music.play("assault")

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

	if GameState.view_3d or "--3d" in OS.get_cmdline_user_args():
		_enable_view_3d()

	# Тайный бросок: есть ли на этом заходе чертёж (игроку не показываем).
	if not _force_boss:
		_hidden_blueprint = GameState.roll_level_blueprint()


func _process(delta: float) -> void:
	if _finished:
		return
	hud.set_progress(director.time / level_data.duration)
	_update_props(delta)
	_follow_camera(delta)
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


## Камера по горизонтали: центр экрана тянется к игроку, но не выходит за мир.
func _follow_camera(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var camera := $Camera as Camera2D
	var span := Arena.rect().size.x - Arena.visible_size().x
	if span <= 0.0:
		return
	var target := clampf(player.position.x - Arena.visible_size().x / 2.0, 0.0, span)
	camera.position.x = lerpf(camera.position.x, target, 1.0 - exp(-camera_follow * delta))


# --- 2.5D-вид (прототип) -------------------------------------------------------

## Картинку рисует 3D-сцена (View3D), 2D-узлы уровня работают как раньше,
## но не видны. HUD — на своём слое, остаётся.
func _enable_view_3d() -> void:
	for node_name in ["Background", "Props", "Pickups", "Enemies", "Projectiles", "Effects", "Clouds"]:
		var node := get_node_or_null(node_name) as CanvasItem
		if node:
			node.visible = false
	# Сам узел игрока прятать нельзя — он мигает `visible` при уроне и снова
	# показался бы. Прячем его картинку (корабль и тень).
	for node_name in ["Visual", "Shadow"]:
		var part := player.get_node_or_null(node_name) as CanvasItem
		if part:
			part.hide()
	var view := View3D.new()
	add_child(view)
	view.setup(self)


# --- Разрушаемые объекты и чертежи --------------------------------------------

## Пока идут волны — время от времени на земле появляются 1–3 объекта.
func _update_props(delta: float) -> void:
	if prop_scene == null or director.is_held() or director.time >= level_data.duration:
		return
	_prop_cooldown -= delta
	if _prop_cooldown > 0.0:
		return
	_prop_cooldown = randf_range(prop_interval_min, prop_interval_max)
	var width := Arena.rect().size.x
	var center := randf_range(140.0, width - 140.0)
	if randf() < 0.45:
		# «База»: крупная постройка, вокруг неё 2–4 мелких.
		_spawn_prop(Vector2(center, -260.0), true)
		for i in randi_range(2, 4):
			var angle := randf() * TAU
			var offset := Vector2(cos(angle), sin(angle)) * randf_range(120.0, 170.0)
			_spawn_prop(Vector2(clampf(center + offset.x, 50.0, width - 50.0), -260.0 + offset.y), false)
	else:
		for i in randi_range(1, 3):
			_spawn_prop(Vector2(clampf(center + randf_range(-110.0, 110.0), 50.0, width - 50.0), -50.0 - 70.0 * i), false)


func _spawn_prop(pos: Vector2, is_large: bool) -> void:
	var prop = prop_scene.instantiate()
	prop.large = is_large
	prop.position = pos
	prop.destroyed.connect(_on_prop_destroyed)
	props.add_child(prop)


func _on_prop_destroyed(prop) -> void:
	_on_enemy_destroyed(prop)
	if _hidden_blueprint == "" or _blueprint_dropped or blueprint_scene == null:
		return
	if randf() < GameState.BLUEPRINT_PROP_CHANCE:
		_blueprint_dropped = true
		var pickup = blueprint_scene.instantiate()
		pickup.position = prop.position
		pickup.collected.connect(_on_blueprint_collected)
		pickups.add_child.call_deferred(pickup)


func _on_blueprint_collected() -> void:
	_found_blueprint = _hidden_blueprint
	hud.show_blueprint(GameState.get_ship(_found_blueprint).title)


# --- Враги и босс -------------------------------------------------------------

func _spawn_enemy(wave: WaveData, pattern: FlightPattern) -> void:
	if _finished:
		return
	var enemy = wave.enemy.instantiate()
	enemy.pattern = pattern
	enemy.max_hp = ceili(enemy.max_hp * level_data.enemy_hp_mult)
	enemy.position = pattern.start_position(Arena.rect().size.x)
	enemy.projectile_container = projectiles
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemies.add_child(enemy)


func _spawn_boss() -> void:
	_boss_spawned = true
	var boss = boss_scene.instantiate()
	boss.max_hp = level_data.boss_hp
	boss.position = Vector2(Arena.rect().size.x / 2.0, -150.0)
	boss.projectile_container = projectiles
	boss.destroyed.connect(_on_enemy_destroyed)
	boss.destroyed.connect(_on_boss_destroyed)
	boss.health_changed.connect(hud.set_boss_health)
	enemies.add_child(boss)
	hud.show_boss(boss.max_hp)
	Music.play("showdown")


## Мини-босс: время уровня стоит, пока он жив (WaveDirector ждёт resume()).
func _spawn_miniboss(_index: int) -> void:
	if miniboss_scene == null or _finished:
		director.resume()
		return
	var boss = miniboss_scene.instantiate()
	boss.max_hp = level_data.miniboss_hp
	boss.position = Vector2(Arena.rect().size.x / 2.0, -120.0)
	boss.projectile_container = projectiles
	boss.destroyed.connect(_on_enemy_destroyed)
	boss.destroyed.connect(_on_miniboss_destroyed)
	boss.health_changed.connect(hud.set_boss_health)
	enemies.add_child(boss)
	hud.show_boss(boss.max_hp, "МИНИБОСС")
	Music.play("showdown")


func _on_miniboss_destroyed(_boss) -> void:
	run_crystals += GameState.CRYSTALS_MINIBOSS
	hud.hide_boss()
	Music.play("assault")
	director.resume()


func _on_boss_destroyed(_boss) -> void:
	run_crystals += GameState.CRYSTALS_BOSS
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
	var first_clear := victory and not GameState.is_level_completed(GameState.current_chapter, GameState.current_level)
	var bonus := GameState.complete_current_level(score) if victory else 0
	if run_crystals > 0:
		GameState.add_crystals(run_crystals)
	var crystals := run_crystals + (GameState.CRYSTALS_FIRST_CLEAR if first_clear else 0)
	GameState.finish_level_blueprint(_found_blueprint, victory)
	var blueprint_line := ""
	if _found_blueprint != "":
		var title := GameState.get_ship(_found_blueprint).title
		blueprint_line = "Чертёж «%s» сохранён: %d/%d" % [title, GameState.blueprint_count(_found_blueprint), GameState.blueprints_required(_found_blueprint)] \
			if victory else "Чертёж «%s» потерян — корабль сбит" % title
	hud.show_results(victory, score, run_stars, bonus, victory and GameState.has_next_level(), crystals, blueprint_line)


func _go_to_map() -> void:
	if not _finished:
		_finish(false)
	Router.level_map()


func _next_level() -> void:
	GameState.select_next_level()
	Router.reload()
