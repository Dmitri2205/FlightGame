class_name CollisionLayers
## Именованные слои 2D-физики. Номера совпадают с [layer_names] в project.godot,
## битовые маски — со значениями collision_layer/collision_mask в .tscn.

# Номера слоёв (для set_collision_layer_value / set_collision_mask_value).
const PLAYER_LAYER := 1
const ENEMY_LAYER := 2
const PLAYER_BULLET_LAYER := 3
const ENEMY_BULLET_LAYER := 4
const PICKUP_LAYER := 5

# Битовые маски (для collision_layer / collision_mask).
const NONE := 0
const PLAYER := 1 << (PLAYER_LAYER - 1)               # 1
const ENEMY := 1 << (ENEMY_LAYER - 1)                 # 2 (воздух и земля)
const PLAYER_BULLET := 1 << (PLAYER_BULLET_LAYER - 1) # 4
const ENEMY_BULLET := 1 << (ENEMY_BULLET_LAYER - 1)   # 8
const PICKUP := 1 << (PICKUP_LAYER - 1)               # 16
