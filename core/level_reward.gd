class_name LevelReward
extends RefCounted
## Что начислено за прохождение уровня сверх собранного в полёте
## (результат GameState.complete_level). Экран итогов только показывает это.

## Бонус звёзд за первое прохождение (LevelData.completion_bonus).
var bonus_stars := 0
## Кристаллы за первое прохождение (Balance.CRYSTALS_FIRST_CLEAR).
var crystals := 0
