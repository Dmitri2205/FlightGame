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
## Пауза после победы над боссом, чтобы успеть собрать звёзды.
@export var victory_delay := 3.0

@export_group("Постройки")
## Пауза до первой группы разрушаемых объектов и между группами, секунд.
@export var first_prop_delay := 2.0
@export var prop_interval_min := 5.0
@export var prop_interval_max := 9.0
## Центр группы — не ближе к краю мира, px.
@export var prop_group_edge := 140.0
## Отдельная постройка — не ближе к краю мира, px.
@export var prop_edge := 50.0
## Шанс, что группа — «база»: крупная постройка, вокруг неё кольцом мелкие.
@export_range(0.0, 1.0) var base_chance := 0.45
## Где появляется центр базы (y, px; выше экрана).
@export var base_spawn_y := -260.0
## Сколько мелких вокруг базы и на каком расстоянии от центра, px.
@export var base_satellites_min := 2
@export var base_satellites_max := 4
@export var base_ring_radius_min := 120.0
@export var base_ring_radius_max := 170.0
## Не база — россыпь мелких: сколько, разброс по x от центра, px,
## первая строка (y, px) и шаг между строками вверх, px.
@export var scatter_count_min := 1
@export var scatter_count_max := 3
@export var scatter_spread_x := 110.0
@export var scatter_start_y := -50.0
@export var scatter_row_step := 70.0

var score := 0
var run_stars := 0
var run_crystals := 0
var level_data: LevelData

var _finished := false
var _boss_spawned := false
var _force_boss := false
var _prop_cooldown := 0.0
## Чертёж какого корабля спрятан на этом заходе ("" — нет) и найден ли он.
var _hidden_blueprint := ""
var _blueprint_dropped := false
var _found_blueprint := ""

@onready var player: Player = $Player
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
	_prop_cooldown = first_prop_delay

	# Сюда FX кладёт взрывы и искры.
	$Effects.add_to_group(Groups.FX_LAYER)
	player.place_at(Arena.player_spawn_point())
	$Camera.position.x = maxf(Arena.rect().size.x - Arena.visible_size().x, 0.0) / 2.0
	player.projectile_container = projectiles
	player.health_changed.connect(hud.set_health)
	player.died.connect(_finish.bind(false))
	hud.menu_requested.connect(_go_to_map)
	hud.retry_requested.connect(Router.reload)
	hud.next_requested.connect(_next_level)
	director.enemy_requested.connect(_spawn_enemy)
	director.miniboss_requested.connect(_spawn_miniboss)
	Music.play(Music.Track.ASSAULT)

	hud.set_health(player.health, player.stats.max_health)
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

	if GameState.settings.view_3d or "--3d" in OS.get_cmdline_user_args():
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
	var center := randf_range(prop_group_edge, width - prop_group_edge)
	if randf() < base_chance:
		# «База»: крупная постройка, вокруг неё кольцом мелкие.
		_spawn_prop(Vector2(center, base_spawn_y), true)
		for i in randi_range(base_satellites_min, base_satellites_max):
			var angle := randf() * TAU
			var offset := Vector2(cos(angle), sin(angle)) * randf_range(base_ring_radius_min, base_ring_radius_max)
			_spawn_prop(Vector2(clampf(center + offset.x, prop_edge, width - prop_edge), base_spawn_y + offset.y), false)
	else:
		for i in randi_range(scatter_count_min, scatter_count_max):
			var x := clampf(center + randf_range(-scatter_spread_x, scatter_spread_x), prop_edge, width - prop_edge)
			_spawn_prop(Vector2(x, scatter_start_y - scatter_row_step * i), false)


func _spawn_prop(pos: Vector2, is_large: bool) -> void:
	var prop := prop_scene.instantiate() as Destructible
	prop.large = is_large
	prop.position = pos
	prop.destroyed.connect(_on_prop_destroyed)
	props.add_child(prop)


func _on_prop_destroyed(prop: EnemyBase) -> void:
	_on_enemy_destroyed(prop)
	if _hidden_blueprint == "" or _blueprint_dropped or blueprint_scene == null:
		return
	if randf() < Balance.BLUEPRINT_PROP_CHANCE:
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
	var enemy := wave.enemy.instantiate() as WaveEnemy
	enemy.setup(pattern, GameState.current_chapter_data().enemy_hp_multiplier(GameState.current_level))
	enemy.projectile_container = projectiles
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemies.add_child(enemy)


func _spawn_boss() -> void:
	_boss_spawned = true
	_spawn_boss_like(boss_scene, level_data.boss_hp, _on_boss_destroyed)


## Мини-босс: время уровня стоит, пока он жив (WaveDirector ждёт resume()).
func _spawn_miniboss(_index: int) -> void:
	if miniboss_scene == null or _finished:
		director.resume()
		return
	var hp: int = GameState.current_chapter_data().miniboss_hp(GameState.current_level)
	_spawn_boss_like(miniboss_scene, hp, _on_miniboss_destroyed, "МИНИБОСС")


## Босс или мини-босс: здоровье из данных уровня, полоска здоровья в HUD,
## музыка боя. on_destroyed — что делать после победы (кроме награды).
func _spawn_boss_like(scene: PackedScene, hp: int, on_destroyed: Callable, title := "") -> void:
	var boss := scene.instantiate() as Boss
	boss.setup(hp)
	boss.projectile_container = projectiles
	boss.destroyed.connect(_on_enemy_destroyed)
	boss.destroyed.connect(on_destroyed)
	boss.health_changed.connect(hud.set_boss_health)
	enemies.add_child(boss)
	if title.is_empty():
		hud.show_boss(boss.max_hp)
	else:
		hud.show_boss(boss.max_hp, title)
	Music.play(Music.Track.SHOWDOWN)


func _on_miniboss_destroyed(_boss: EnemyBase) -> void:
	run_crystals += Balance.CRYSTALS_MINIBOSS
	hud.hide_boss()
	Music.play(Music.Track.ASSAULT)
	director.resume()


func _on_boss_destroyed(_boss: EnemyBase) -> void:
	run_crystals += Balance.CRYSTALS_BOSS
	hud.hide_boss()
	get_tree().create_timer(victory_delay, false).timeout.connect(_finish.bind(true))


func _on_enemy_destroyed(enemy: EnemyBase) -> void:
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
	# Награда за прохождение (бонус звёзд, кристаллы первого прохождения)
	# начисляет GameState — здесь её только показываем.
	var reward := GameState.complete_level(score) if victory else LevelReward.new()
	if run_crystals > 0:
		GameState.add_crystals(run_crystals)
	GameState.finish_level_blueprint(_found_blueprint, victory)
	var blueprint_line := ""
	if _found_blueprint != "":
		var title := GameState.get_ship(_found_blueprint).title
		blueprint_line = "Чертёж «%s» сохранён: %d/%d" % [title, GameState.blueprint_count(_found_blueprint), GameState.blueprints_required(_found_blueprint)] \
			if victory else "Чертёж «%s» потерян — корабль сбит" % title
	hud.show_results(victory, score, run_stars, reward.bonus_stars, victory and GameState.has_next_level(), run_crystals + reward.crystals, blueprint_line)


func _go_to_map() -> void:
	if not _finished:
		_finish(false)
	Router.level_map()


func _next_level() -> void:
	GameState.select_next_level()
	Router.reload()
