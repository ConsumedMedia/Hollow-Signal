class_name CombatState
extends RefCounted
## Runtime battle data only; no nodes, effects, timers, or presentation objects.

var actors: Array[ActorState] = []
var active_actor_id: StringName = &""
var round_number: int = 1
var turn_number: int = 0
var outcome: StringName = &"ongoing"


func get_actor(actor_id: StringName) -> ActorState:
	for actor: ActorState in actors:
		if actor.id == actor_id:
			return actor
	return null


func get_opponent(actor: ActorState) -> ActorState:
	for candidate: ActorState in actors:
		if candidate.side != actor.side:
			return candidate
	return null
