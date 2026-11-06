class_name EnemyInfo
extends RefCounted
## То, что о враге нужно знать без боя (расписание волн, призраки превью):
## скорость, спрайт и наземный ли он. Берётся из сцены врага один раз
## (сцену приходится создавать) и кэшируется.

var speed := 0.0
var texture: Texture2D
var is_ground := false

static var _cache := {}


## Сведения о враге по его сцене (корень сцены — WaveEnemy).
static func of(scene: PackedScene) -> EnemyInfo:
	if not _cache.has(scene):
		var info := EnemyInfo.new()
		var enemy := scene.instantiate() as WaveEnemy
		assert(enemy != null, "%s: корень сцены врага волны должен быть WaveEnemy" % scene.resource_path)
		info.speed = enemy.speed
		info.is_ground = enemy is GroundUnit
		var sprite := enemy.get_node_or_null("Sprite") as Sprite2D
		info.texture = sprite.texture if sprite else null
		enemy.free()
		_cache[scene] = info
	return _cache[scene]
