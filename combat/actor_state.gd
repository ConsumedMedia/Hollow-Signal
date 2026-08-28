class_name ActorState
extends RefCounted
## One mutable participant, separate from the shared authored definition.

enum Team { CREW, ENEMY }

var id: StringName
var definition: ActorDefinition
var side: Team
var health: int


func _init(actor_id: StringName, actor_definition: ActorDefinition, actor_side: Team) -> void:
	id = actor_id
	definition = actor_definition
	side = actor_side
	health = definition.max_health


func is_conscious() -> bool:
	return health > 0


func short_name() -> String:
	return ("C" if side == Team.CREW else "E") + String(id).get_slice("_", 1)
