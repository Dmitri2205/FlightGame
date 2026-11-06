extends Node
## Фоновая музыка. Подключено как autoload `Music`.
##
## Обе дорожки играют одновременно, а слышна одна: смена — плавный переход
## громкости, поэтому после мини-босса боевая тема продолжается с того же
## места, а не начинается заново. Работает и на паузе игры.
## Дорожки играют в шину Music: её громкость и выключение (ползунок в
## настройках, переключатель в меню паузы) — GameState.apply_audio().
##
##   Music.play("assault")    # меню, карта, уровень
##   Music.play("showdown")   # мини-босс и босс
##
## Треки сгенерированы в Suno AI (audio/music/*.ogg).

const TRACKS := {
	"assault": preload("res://audio/music/hyperdrive_assault.ogg"),
	"showdown": preload("res://audio/music/hyperdrive_showdown.ogg"),
}
## Громкость слышимой дорожки внутри шины Music, дБ.
const VOLUME_DB := -6.0
const SILENT_DB := -60.0
## Длительность перехода между дорожками, с.
const FADE := 1.2

var _players := {}
var _tweens := {}
var _current := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Без экрана (CI, тесты) звука всё равно нет, а незавершённое
	# воспроизведение при выходе движок считает утечкой ресурсов.
	if DisplayServer.get_name() == "headless":
		return
	for key in TRACKS:
		var stream = TRACKS[key].duplicate()
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = SILENT_DB
		player.bus = AudioBuses.MUSIC
		add_child(player)
		_players[key] = player
	play("assault")


## Сделать слышной дорожку key (остальные плавно затихают).
func play(key: String) -> void:
	if key == _current or not _players.has(key):
		return
	_current = key
	for track in _players:
		var player: AudioStreamPlayer = _players[track]
		var audible: bool = track == _current
		if audible and not player.playing:
			player.play()
		if _tweens.has(track) and _tweens[track].is_valid():
			_tweens[track].kill()
		var tween := create_tween()
		_tweens[track] = tween
		tween.tween_property(player, "volume_db", VOLUME_DB if audible else SILENT_DB, FADE)


## При выходе из игры: остановить дорожки и отпустить потоки — иначе движок
## считает их «ресурсами, оставшимися в памяти» (ошибка в логе выхода).
func _exit_tree() -> void:
	for key in _tweens:
		if _tweens[key].is_valid():
			_tweens[key].kill()
	_tweens.clear()
	for key in _players:
		var player: AudioStreamPlayer = _players[key]
		player.stop()
		player.stream = null
