class_name AudioBuses
extends RefCounted
## Шины звука (default_bus_layout.tres): Master ← Music, SFX.
## Громкость шин задают настройки (GameState.music_volume / sfx_volume).
##
## Музыка (core/music.gd) играет в шину Music. Будущие звуки — взрывы,
## выстрелы, гибель игрока — достаточно завести в шину SFX, ползунок
## «Эффекты» в настройках подхватит их сам:
##   player.bus = AudioBuses.SFX   # или bus = "SFX" в инспекторе

const MUSIC := &"Music"
const SFX := &"SFX"
## Ниже этого линейная громкость считается нулём (linear_to_db(0) = -inf).
const MIN_VOLUME := 0.001


## Задать громкость шины: volume — линейная 0..1; при 0 или muted шина молчит.
static func apply(bus: StringName, volume: float, muted := false) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_error("Нет шины звука «%s» (default_bus_layout.tres)" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, MIN_VOLUME)))
	AudioServer.set_bus_mute(index, muted or volume < MIN_VOLUME)
