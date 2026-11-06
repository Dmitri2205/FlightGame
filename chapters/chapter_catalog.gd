class_name ChapterCatalog
extends RefCounted
## Единая точка доступа к главам. Порядок = порядок прохождения
## (индекс главы хранится в сохранении — не переставлять).

const _CHAPTERS := [
	preload("res://chapters/mars/chapter.tres"),
	preload("res://chapters/cryos/chapter.tres"),
	preload("res://chapters/toxida/chapter.tres"),
]


static func all() -> Array[ChapterData]:
	var result: Array[ChapterData] = []
	result.assign(_CHAPTERS)
	return result


static func count() -> int:
	return _CHAPTERS.size()


## Глава по индексу (с ограничением диапазона).
static func get_by_index(index: int) -> ChapterData:
	return _CHAPTERS[clampi(index, 0, _CHAPTERS.size() - 1)]


## Глава по id; неизвестный id — null.
static func get_by_id(id: String) -> ChapterData:
	for chapter in _CHAPTERS:
		if chapter.id == id:
			return chapter
	return null
