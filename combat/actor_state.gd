class_name ActorState
extends RefCounted
## One mutable participant, separate from the shared authored definition.

enum Team { CREW, ENEMY }

var id: StringName
var definition: ActorDefinition
var side: Team
var health: int
var strain: int = 0
var shaken: bool = false
var dead: bool = false
var statuses: Array[StatusState] = []
var uses: Dictionary[StringName, int] = {}
var max_health: int
var speed_bonus: int = 0
var damage_bonus: int = 0
var healing_bonus: int = 0
var strain_relief_bonus: int = 0


func _init(actor_id: StringName, actor_definition: ActorDefinition, actor_side: Team) -> void:
	id = actor_id
	definition = actor_definition
	side = actor_side
	max_health = definition.max_health
	health = max_health


func speed() -> int:
	return definition.speed + speed_bonus


func is_conscious() -> bool:
	return health > 0 and not dead


func is_downed() -> bool:
	return side == Team.CREW and health == 0 and not dead


func get_status(kind: StatusDefinition.Kind) -> StatusState:
	for status: StatusState in statuses:
		if status.definition.kind == kind:
			return status
	return null


func short_name() -> String:
	return ("C" if side == Team.CREW else "E") + String(id).get_slice("_", 1)
