extends Node
## Пул часто создаваемых узлов (пули). Вместо instantiate() + queue_free()
## на каждый выстрел пуля, отлетав своё, снимается со сцены и ждёт здесь
## следующего выстрела — создавать её заново дорого, а пуль десятки в секунду.
## Подключено как autoload `Pool`.
##
##   var bullet = Pool.take(bullet_scene)   # из пула или новая
##   ...настроить, add_child(bullet)
##   Pool.release(bullet)                   # вместо queue_free()

## Больше этого числа свободных узлов одного вида не храним — лишние удаляем.
const MAX_IDLE := 256

## путь сцены → свободные узлы (вне дерева).
var _idle := {}


func take(scene: PackedScene) -> Node:
	var idle: Array = _idle.get(scene.resource_path, [])
	while not idle.is_empty():
		var node = idle.pop_back()
		if is_instance_valid(node):
			return node
	var fresh := scene.instantiate()
	fresh.set_meta("pool_key", scene.resource_path)
	return fresh


## Вернуть узел в пул. Можно звать из обработчиков коллизий: снимается со
## сцены отложенно. Узлы не из пула просто удаляются.
func release(node: Node) -> void:
	if not node.has_meta("pool_key"):
		node.queue_free()
		return
	_stash.call_deferred(node)


func _stash(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var key: String = node.get_meta("pool_key")
	if not _idle.has(key):
		_idle[key] = []
	var idle: Array = _idle[key]
	if idle.size() >= MAX_IDLE:
		node.queue_free()
		return
	node.get_parent().remove_child(node)
	idle.append(node)


## Узлы вне дерева сами не удалятся — чистим при выходе из игры.
func _exit_tree() -> void:
	for key in _idle:
		for node in _idle[key]:
			if is_instance_valid(node):
				node.free()
	_idle.clear()
