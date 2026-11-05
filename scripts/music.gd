extends Node
## Фоновая музыка. Подключено как autoload `Music`.
##
## Обе дорожки играют одновременно, а слышна одна: смена — плавный переход
## громкости, поэтому после мини-босса боевая тема продолжается с того же
## места, а не начинается заново. Работает и на паузе игры.
##
##   Music.play("assault")    # меню, карта, уровень
##   Music.play("showdown")   # мини-босс и босс
##
## Треки сгенерированы в Suno AI (audio/music/*.ogg).

const TRACKS := {
	"assault": preload("res://audio/music/hyperdrive_assault.ogg"),
	"showdown": preload("res://audio/music/hyperdrive_showdown.ogg"),
}
## Громкость музыки, дБ.
const VOLUME_DB := -6.0
const SILENT_DB := -60.0
## Длительность перехода между дорожками, с.
const FADE := 1.2

var _players := {}
var _tweens := {}
var _current := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in TRACKS:
		var stream = TRACKS[key].duplicate()
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = SILENT_DB
		add_child(player)
		_players[key] = player
	GameState.music_changed.connect(_apply_enabled)
	play("assault")


## Сделать слышной дорожку key (остальные плавно затихают).
func play(key: String) -> void:
	if key == _current or not _players.has(key):
		return
	_current = key
	_apply_enabled(GameState.music_on)


func _apply_enabled(enabled: bool) -> void:
	for key in _players:
		var player: AudioStreamPlayer = _players[key]
		var audible: bool = enabled and key == _current
		if audible and not player.playing:
			player.play()
		if _tweens.has(key) and _tweens[key].is_valid():
			_tweens[key].kill()
		var tween := create_tween()
		_tweens[key] = tween
		tween.tween_property(player, "volume_db", VOLUME_DB if audible else SILENT_DB, FADE)
		if not enabled:
			tween.tween_callback(player.stop)
