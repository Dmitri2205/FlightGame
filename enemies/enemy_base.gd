class_name EnemyBase
extends Area2D
## Всё, по чему стреляет игрок: враги из волн, боссы, постройки.
## Общее у них — здоровье, награда за уничтожение (очки, звёзды), вспышка при
## попадании, взрыв при гибели, пушка (у кого есть) и 3D-модель для 3D-вида.
## Уровень работает с любым из них через этот тип.

signal destroyed(enemy: EnemyBase)

@export_group("Награда")
## Очки за уничтожение.
@export var score_value := 0
## Сколько звёзд выпадает при гибели.
@export var star_drop := 0

@export_group("Оружие")
## Чем стреляет; пусто — не стреляет.
@export var gun: GunData

@export_group("Вид")
## Размер взрыва при гибели (1 — обычный).
@export var explosion_size := 1.0
## Вспышка при попадании: цвет (больше 1 — пересвет) и время возврата.
@export var hit_flash := Color(3, 3, 3)
@export var hit_flash_time := 0.1
## Модель пака (models/<имя>.glb) для 3D-вида. Обязательна —
## tests/validate_data.gd проверяет её у каждой сцены врага.
@export var model_3d: StringName

## Куда добавлять пули. Выставляет уровень до add_child.
var projectile_container: Node
## Текущее здоровье. Начальное задаёт наследник в _ready.
var hp := 0

var _dead := false
var _flash_tween: Tween


func take_damage(amount: int) -> void:
	if _dead or not _is_vulnerable():
		return
	var previous := hp
	hp = maxi(hp - amount, 0)
	_flash()
	_on_damaged(previous)
	if hp == 0:
		_die()


func is_destroyed() -> bool:
	return _dead


## Выстрел пушкой из точки `pos` в направлении `direction`.
## null — пушки нет или уровень не дал контейнер для пуль.
func _shoot(pos: Vector2, direction: Vector2) -> Node2D:
	if gun == null or projectile_container == null:
		return null
	return gun.fire(projectile_container, pos, direction)


## Ближайший игрок (или null, если его нет — например, погиб).
func _player() -> Node2D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node2D


## Взрыв, награда (сигнал destroyed — её выдаёт уровень), удаление.
func _die() -> void:
	_dead = true
	FX.explosion(global_position, explosion_size)
	destroyed.emit(self)
	queue_free()


## Можно ли сейчас ранить (босс неуязвим, пока выплывает).
func _is_vulnerable() -> bool:
	return true


## После уменьшения hp (до проверки гибели). previous_hp — здоровье до удара.
func _on_damaged(_previous_hp: int) -> void:
	pass


## Цвет, к которому возвращается вспышка.
func _base_modulate() -> Color:
	return Color.WHITE


## Один твин на объект: под плотным огнём новый не плодим, а перезапускаем.
func _flash() -> void:
	modulate = hit_flash
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", _base_modulate(), hit_flash_time)
