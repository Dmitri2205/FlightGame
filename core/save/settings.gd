class_name Settings
extends RefCounted
## Настройки игрока — сброс прогресса их не трогает. Сохраняются вместе
## с Progress в один save.json (ключи не менять). Изменяются через GameState
## (set_music, set_music_volume, …), который применяет и сохраняет их.

## Громкость по умолчанию (линейная 0..1) — музыка и эффекты.
const DEFAULT_VOLUME := 0.8

## Инструменты разработчика (превью волн, тесты) в меню. Скрыты от игрока:
## включаются 7 тапами по названию в главном меню; в отладочной сборке — всегда.
var dev_mode := false
## Звук. Громкость — ползунки в настройках (линейная 0..1), music_on —
## переключатель в меню паузы: глушит шину Music, не трогая громкость.
var music_on := true
var music_volume := DEFAULT_VOLUME
var sfx_volume := DEFAULT_VOLUME
## Прототип 2.5D-вида (камера сзади-сверху), переключатель в меню разработчика.
var view_3d := false


func to_dict() -> Dictionary:
	return {
		"dev_mode": dev_mode,
		"music_on": music_on,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"view_3d": view_3d,
	}


## Недостающие ключи — значения по умолчанию.
static func from_dict(data: Dictionary) -> Settings:
	var s := Settings.new()
	s.dev_mode = bool(data.get("dev_mode", s.dev_mode))
	s.music_on = bool(data.get("music_on", s.music_on))
	s.music_volume = clampf(float(data.get("music_volume", s.music_volume)), 0.0, 1.0)
	s.sfx_volume = clampf(float(data.get("sfx_volume", s.sfx_volume)), 0.0, 1.0)
	s.view_3d = bool(data.get("view_3d", s.view_3d))
	return s
