class_name Groups
## Имена групп узлов — в одном месте (по образцу CollisionLayers): узел
## добавляет себя в группу add_to_group(Groups.X), остальные ищут по тем же
## константам. Литералы групп в коде и в .tscn не писать.

## Корабль игрока (Player).
const PLAYER := &"player"
## Живые враги (WaveEnemy, Boss) — цели ракет, двойники 3D-вида.
const ENEMIES := &"enemies"
## Разрушаемые постройки на земле (Destructible) — не цели ракет.
const DESTRUCTIBLES := &"destructibles"
## Слой, куда FX кладёт эффекты (узел Effects уровня).
const FX_LAYER := &"fx_layer"
