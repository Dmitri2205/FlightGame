extends Node2D
## Поверхность планеты: бесконечно прокручиваемая земля с пятнами грунта
## и декором (кратеры, скалы, кристаллы — спрайты art/sprites/<префикс>*.png).
## Цвет земли и набор декора берутся из главы (ChapterData).

class Patch:
	var pos: Vector2
	var radius: float
	var color: Color

class Decor:
	var pos: Vector2
	var texture: Texture2D
	var flip: bool

## Имена спрайтов декора (без префикса биома); повторы — чаще встречаются.
const DECOR_NAMES := [
	"crater", "crater", "crater_large", "rock", "rock_large_a", "rock_large_b",
	"rocks_small_a", "rocks_small_a", "rocks_small_b", "rocks_small_b",
	"crystals", "crystals_large", "meteor",
]

## Своя скорость прокрутки, px/с, — для декоративного фона (карта уровней).
## 0 — земля боя: Arena.GROUND_SCROLL_SPEED (уровень, превью, меню).
@export var scroll_speed := 0.0
@export var base_color := Color(0.6, 0.35, 0.27)
## Текстура грунта (бесшовная по вертикали, шириной в экран). Есть — пятна
## не рисуются, земля — эта текстура, прокручиваемая вниз.
@export var ground_texture: Texture2D
## Затемнение декора, чтобы скалы и кратеры не «светились» на фоне грунта.
@export var decor_tint := Color(0.86, 0.86, 0.86)
@export var patch_count := 30
@export var decor_count := 12
## true — оформление берётся из текущей главы GameState при запуске.
@export var use_current_chapter := true

var _patches: Array[Patch] = []
var _decor: Array[Decor] = []
var _decor_textures: Array[Texture2D] = []
## Сколько проехала земля (для прокрутки текстуры).
var _scrolled := 0.0


func _ready() -> void:
	if use_current_chapter:
		apply_chapter(GameState.current_chapter_data())
	else:
		if ground_texture == null:
			ground_texture = load("res://art/ground/mars.jpg") as Texture2D
		_load_decor("decor_")
		_build()


## Перекрасить землю и сменить декор под главу (планету).
func apply_chapter(chapter: ChapterData) -> void:
	base_color = chapter.ground_color
	ground_texture = chapter.ground_texture
	_load_decor(chapter.decor_prefix)
	_build()


func _load_decor(prefix: String) -> void:
	_decor_textures.clear()
	for decor_name in DECOR_NAMES:
		var texture := load("res://art/sprites/%s%s.png" % [prefix, decor_name]) as Texture2D
		if texture:
			_decor_textures.append(texture)


func _build() -> void:
	_patches.clear()
	_decor.clear()
	var size := Arena.rect().size
	for i in patch_count:
		var patch := Patch.new()
		patch.pos = Vector2(randf() * size.x, randf() * size.y)
		_randomize_patch(patch)
		_patches.append(patch)
	for i in decor_count:
		var decor := Decor.new()
		_randomize_decor(decor, randf_range(-150.0, size.y))
		_decor.append(decor)


func _process(delta: float) -> void:
	var size := Arena.rect().size
	var shift := _speed() * delta
	_scrolled += shift
	for patch in _patches:
		patch.pos.y += shift
		if patch.pos.y - patch.radius > size.y:
			patch.pos = Vector2(randf() * size.x, -patch.radius)
			_randomize_patch(patch)
	for decor in _decor:
		decor.pos.y += shift
		if decor.texture == null or decor.pos.y - decor.texture.get_height() / 2.0 > size.y:
			_randomize_decor(decor, -randf_range(150.0, 600.0))
	queue_redraw()


func _speed() -> float:
	return scroll_speed if scroll_speed > 0.0 else Arena.GROUND_SCROLL_SPEED


func _draw() -> void:
	var screen := Arena.rect().size
	if ground_texture:
		# Текстура растянута на ширину экрана и повторяется по вертикали.
		var tile := ground_texture.get_size() * (screen.x / ground_texture.get_width())
		var y := fmod(_scrolled, tile.y) - tile.y
		while y < screen.y:
			draw_texture_rect(ground_texture, Rect2(Vector2(0, y), tile), false)
			y += tile.y
	else:
		draw_rect(Rect2(Vector2.ZERO, screen), base_color)
		for patch in _patches:
			draw_circle(patch.pos, patch.radius, patch.color)
	for decor in _decor:
		if decor.texture == null:
			continue
		var size := decor.texture.get_size()
		var rect := Rect2(decor.pos - size / 2.0, size)
		if decor.flip:
			rect.size.x = -rect.size.x
			rect.position.x += size.x
		draw_texture_rect(decor.texture, rect, false, decor_tint)


func _randomize_patch(patch: Patch) -> void:
	patch.radius = randf_range(30.0, 110.0)
	if randf() < 0.5:
		patch.color = base_color.darkened(randf_range(0.06, 0.14))
	else:
		patch.color = base_color.lightened(randf_range(0.05, 0.12))
	patch.color.a = 0.6


func _randomize_decor(decor: Decor, y: float) -> void:
	decor.texture = _decor_textures.pick_random()
	decor.pos = Vector2(randf() * Arena.rect().size.x, y)
	decor.flip = randf() < 0.5
