class_name CombatState
extends RefCounted
## Formation and the round's turn queue are separate, both keyed by stable IDs.

var actors: Array[ActorState] = []
var crew_ranks: Array[StringName] = []
var enemy_ranks: Array[StringName] = []
var round_order: Array[StringName] = []
var initiative_rolls: Dictionary[StringName, int] = {}
var initiative_scores: Dictionary[StringName, int] = {}
var turn_cursor: int = 0
var active_actor_id: StringName = &""
var round_number: int = 1
var turn_number: int = 0
var outcome: StringName = &"ongoing"


func get_actor(actor_id: StringName) -> ActorState:
	for actor: ActorState in actors:
		if actor.id == actor_id:
			return actor
	return null


func get_ranks(team: ActorState.Team) -> Array[StringName]:
	return crew_ranks if team == ActorState.Team.CREW else enemy_ranks


func get_rank(actor_id: StringName) -> int:
	var actor: ActorState = get_actor(actor_id)
	return get_ranks(actor.side).find(actor_id) + 1 if actor != null else 0


func actor_at(team: ActorState.Team, rank: int) -> ActorState:
	var ranks: Array[StringName] = get_ranks(team)
	return get_actor(ranks[rank - 1]) if rank >= 1 and rank <= ranks.size() else null
