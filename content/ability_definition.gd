class_name AbilityDefinition
extends Resource
## Shared authored ability. Move and Wait remain universal rules.

enum TargetTeam { OPPONENT, ALLY }

@export var id: StringName = &""
@export var display_name: String = ""
@export var actor_ranks: Array[int] = [1, 2]
@export var target_ranks: Array[int] = [1, 2]
@export_range(0, 1000) var damage_min: int = 6
@export_range(0, 1000) var damage_max: int = 8
@export var target_team: TargetTeam = TargetTeam.OPPONENT
@export var allow_self: bool = true
@export_range(0, 20) var max_uses: int = 0
@export_range(1.0, 3.0) var exposed_multiplier: float = 1.0
@export var effects: Array[EffectDefinition] = []
@export_multiline var description: String = ""


func is_valid() -> bool:
	if id.is_empty() or id in [&"move", &"wait"] or display_name.is_empty() \
		or not _valid_ranks(actor_ranks) or not _valid_ranks(target_ranks) \
		or damage_min < 0 or damage_max < damage_min or max_uses < 0 \
		or not is_finite(exposed_multiplier) or exposed_multiplier < 1.0 \
		or target_team not in [TargetTeam.OPPONENT, TargetTeam.ALLY]:
		return false
	for effect: EffectDefinition in effects:
		if effect == null or not effect.is_valid():
			return false
	return damage_max > 0 or not effects.is_empty()


func _valid_ranks(ranks: Array[int]) -> bool:
	if ranks.is_empty():
		return false
	var seen: Array[int] = []
	for rank: int in ranks:
		if rank < 1 or rank > 4 or rank in seen:
			return false
		seen.append(rank)
	return true
