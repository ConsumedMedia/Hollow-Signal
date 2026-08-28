class_name CombatEvent
extends RefCounted
## Value snapshots for presentation; never a reference to changing actor state.

var kind: StringName
var source_id: StringName
var target_id: StringName
var amount: int
var health_after: int = 0
var strain_after: int = 0
var power_after: int = 0
var status_name: String = ""
var duration: int = 0
var ability_name: String = ""
var round_number: int = 0
var outcome: StringName = &""
var source_name: String = ""
var target_name: String = ""
var source_rank: int = 0
var target_rank: int = 0
var rank_ids: Array[StringName] = []
var team: ActorState.Team = ActorState.Team.CREW


func _init(event_kind: StringName, source: StringName = &"", target: StringName = &"", value: int = 0) -> void:
	kind = event_kind
	source_id = source
	target_id = target
	amount = value
