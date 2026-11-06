extends Node
## Фоновая музыка. Подключено как autoload `Music`.
##
## Обе дорожки играют одновременно, а слышна одна: смена — плавный переход
## громкости, поэтому после мини-босса боевая тема продолжается с того же
## места, а не начинается заново. Работает и на паузе игры.
## Дорожки играют в шину Music: её громкость и выключение (ползунок в
## настройках, переключатель в меню паузы) — GameState.apply_audio().
##
##   Music.play(Music.Track.ASSAULT)    # меню, карта, уровень
##   Music.play(Music.Track.SHOWDOWN)   # мини-босс и босс
##
## Треки сгенерированы в Suno AI (audio/music/*.ogg).

enum Track { ASSAULT, SHOWDOWN }

const TRACKS := {
	Track.ASSAULT: preload("res://audio/music/hyperdrive_assault.ogg"),
	Track.SHOWDOWN: preload("res://audio/music/hyperdrive_showdown.ogg"),
}
## Громкость слышимой дорожки внутри шины Music, дБ.
const VOLUME_DB := -6.0
const SILENT_DB := -60.0
## Длительность перехода между дорожками, с.
const FADE := 1.2

## Track → AudioStreamPlayer / Tween его громкости.
var _players := {}
var _tweens := {}
## Слышимая дорожка; -1 — пока ни одной.
var _current := -1


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
	play(Track.ASSAULT)


## Сделать слышной дорожку track (остальные плавно затихают).
func play(track: Track) -> void:
	if track == _current or not _players.has(track):
		return
	_current = track
	for key in _players:
		var player: AudioStreamPlayer = _players[key]
		var audible: bool = key == _current
		if audible and not player.playing:
			player.play()
		if _tweens.has(key) and _tweens[key].is_valid():
			_tweens[key].kill()
		var tween := create_tween()
		_tweens[key] = tween
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
