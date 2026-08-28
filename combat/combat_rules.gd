class_name CombatRules
extends RefCounted
## All gameplay mutations and random rolls are here. No SceneTree dependency.

const MAX_RANKS: int = 4


static func create_battle(crew: Array[ActorDefinition], enemy: Array[ActorDefinition],
		rng: RandomNumberGenerator) -> CombatState:
	if rng == null or crew.size() > MAX_RANKS or enemy.size() > MAX_RANKS:
		return null
	for definition: ActorDefinition in crew + enemy:
		if definition == null or not definition.is_valid():
			return null
	var state: CombatState = CombatState.new()
	for index: int in range(crew.size()):
		var actor: ActorState = ActorState.new(StringName("crew_%d" % (index + 1)), crew[index], ActorState.Team.CREW)
		state.actors.append(actor)
		state.crew_ranks.append(actor.id)
	for index: int in range(enemy.size()):
		var actor: ActorState = ActorState.new(StringName("enemy_%d" % (index + 1)), enemy[index], ActorState.Team.ENEMY)
		state.actors.append(actor)
		state.enemy_ranks.append(actor.id)
	state.outcome = _get_outcome(state)
	if state.outcome == &"ongoing":
		_start_round(state, rng)
	return state


static func get_legal_actions(state: CombatState, actor_id: StringName) -> Array[ActionCommand]:
	var legal: Array[ActionCommand] = []
	if state == null or state.outcome != &"ongoing" or state.active_actor_id != actor_id:
		return legal
	var actor: ActorState = state.get_actor(actor_id)
	if actor == null or not actor.is_conscious():
		return legal
	for ability: AbilityDefinition in actor.definition.abilities:
		for target: ActorState in state.actors:
			var attack: ActionCommand = ActionCommand.new(actor_id, ability.id, [target.id], state.turn_number)
			if validate_action(state, attack).is_empty():
				legal.append(attack)
	for ally_id: StringName in state.get_ranks(actor.side):
		var move: ActionCommand = ActionCommand.new(actor_id, &"move", [ally_id], state.turn_number)
		if validate_action(state, move).is_empty():
			legal.append(move)
	legal.append(ActionCommand.new(actor_id, &"wait", [], state.turn_number))
	return legal


static func ability_reason(state: CombatState, actor_id: StringName, ability_id: StringName) -> String:
	# Read-only rank/target availability, even for an actor whose turn is over.
	if state == null:
		return "No battle."
	var actor: ActorState = state.get_actor(actor_id)
	if actor == null or not actor.is_conscious():
		return "Actor is defeated."
	var ability: AbilityDefinition = actor.definition.get_ability(ability_id)
	if ability == null:
		return "Unknown ability."
	if not ability.is_valid():
		return "Invalid ability definition."
	var rank: int = state.get_rank(actor_id)
	if rank not in ability.actor_ranks:
		return "Needs actor ranks %s; current rank %d." % [rank_text(ability.actor_ranks), rank]
	for target: ActorState in state.actors:
		if target.side != actor.side and target.is_conscious() and state.get_rank(target.id) in ability.target_ranks:
			return ""
	return "No opponent in target ranks %s." % rank_text(ability.target_ranks)


static func rank_text(ranks: Array[int]) -> String:
	var labels: PackedStringArray = []
	for rank: int in ranks:
		labels.append(str(rank))
	return ", ".join(labels)


static func validate_action(state: CombatState, command: ActionCommand) -> String:
	if state == null or command == null:
		return "Missing battle or command."
	if state.outcome != &"ongoing":
		return "The battle has ended."
	if command.expected_turn != state.turn_number:
		return "That command belongs to an earlier or different turn."
	var actor: ActorState = state.get_actor(command.actor_id)
	if actor == null or command.actor_id != state.active_actor_id:
		return "It is not that actor's turn."
	if not actor.is_conscious():
		return "A defeated actor cannot act."
	if command.action_id == &"wait":
		return "Wait does not take a target." if not command.target_ids.is_empty() else ""
	if command.target_ids.size() != 1:
		return "Choose exactly one target."
	var target: ActorState = state.get_actor(command.target_ids[0])
	if target == null or not target.is_conscious():
		return "Target is missing or defeated."
	if command.action_id == &"move":
		if target.side != actor.side or absi(state.get_rank(actor.id) - state.get_rank(target.id)) != 1:
			return "Move swaps with an adjacent ally only."
		return ""
	var reason: String = ability_reason(state, actor.id, command.action_id)
	if not reason.is_empty():
		return reason
	var ability: AbilityDefinition = actor.definition.get_ability(command.action_id)
	if target.side == actor.side:
		return "Attack needs an opponent."
	if state.get_rank(target.id) not in ability.target_ranks:
		return "Target must be in enemy ranks %s." % rank_text(ability.target_ranks)
	return ""


static func resolve_action(state: CombatState, command: ActionCommand, rng: RandomNumberGenerator) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	if rng == null or not validate_action(state, command).is_empty():
		return events
	var actor: ActorState = state.get_actor(command.actor_id)
	if command.action_id == &"wait":
		events.append(_event(&"wait", actor))
	elif command.action_id == &"move":
		var ally: ActorState = state.get_actor(command.target_ids[0])
		var from_rank: int = state.get_rank(actor.id)
		var to_rank: int = state.get_rank(ally.id)
		var ranks: Array[StringName] = state.get_ranks(actor.side)
		ranks[from_rank - 1] = ally.id
		ranks[to_rank - 1] = actor.id
		var moved: CombatEvent = _event(&"moved", actor, ally)
		moved.source_rank = from_rank
		moved.target_rank = to_rank
		moved.rank_ids = ranks.duplicate()
		events.append(moved)
	else:
		var target: ActorState = state.get_actor(command.target_ids[0])
		var ability: AbilityDefinition = actor.definition.get_ability(command.action_id)
		var damage: int = mini(target.health, rng.randi_range(ability.damage_min, ability.damage_max))
		target.health -= damage
		var hit: CombatEvent = _event(&"damage", actor, target)
		hit.amount = damage
		hit.health_after = target.health
		events.append(hit)
		if not target.is_conscious():
			var defeated: CombatEvent = _event(&"defeated", actor, target)
			defeated.target_rank = state.get_rank(target.id)
			events.append(defeated)
			state.get_ranks(target.side).erase(target.id)
			state.actors.erase(target)
			var compacted: CombatEvent = _event(&"ranks_compacted", actor)
			compacted.team = target.side
			compacted.rank_ids = state.get_ranks(target.side).duplicate()
			events.append(compacted)

	state.turn_number += 1
	state.outcome = _get_outcome(state)
	if state.outcome != &"ongoing":
		state.active_actor_id = &""
		var ended: CombatEvent = CombatEvent.new(&"battle_ended")
		ended.outcome = state.outcome
		events.append(ended)
		return events
	_advance_turn(state, rng, events)
	return events


static func _start_round(state: CombatState, rng: RandomNumberGenerator) -> void:
	state.round_order.clear()
	state.initiative_rolls.clear()
	state.initiative_scores.clear()
	for actor: ActorState in state.actors:
		if actor.is_conscious():
			state.round_order.append(actor.id)
	# Draw in canonical ID order, never formation/storage order.
	state.round_order.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for actor_id: StringName in state.round_order:
		var roll: int = rng.randi_range(1, 6)
		state.initiative_rolls[actor_id] = roll
		state.initiative_scores[actor_id] = state.get_actor(actor_id).definition.speed + roll
	state.round_order.sort_custom(func(a: StringName, b: StringName) -> bool:
		if state.initiative_scores[a] == state.initiative_scores[b]:
			return String(a) < String(b)
		return state.initiative_scores[a] > state.initiative_scores[b])
	state.turn_cursor = 0
	state.active_actor_id = state.round_order[0]


static func _advance_turn(state: CombatState, rng: RandomNumberGenerator, events: Array[CombatEvent]) -> void:
	state.turn_cursor += 1
	while state.turn_cursor < state.round_order.size():
		var actor: ActorState = state.get_actor(state.round_order[state.turn_cursor])
		if actor != null and actor.is_conscious():
			state.active_actor_id = actor.id
			break
		state.turn_cursor += 1
	if state.turn_cursor == state.round_order.size():
		state.round_number += 1
		_start_round(state, rng)
		var round_event: CombatEvent = CombatEvent.new(&"round_started")
		round_event.round_number = state.round_number
		round_event.rank_ids = state.round_order.duplicate()
		events.append(round_event)
	var next_turn: CombatEvent = _event(&"turn_started", state.get_actor(state.active_actor_id))
	next_turn.round_number = state.round_number
	events.append(next_turn)


static func _event(kind: StringName, source: ActorState, target: ActorState = null) -> CombatEvent:
	var event: CombatEvent = CombatEvent.new(kind, source.id)
	event.source_name = source.short_name()
	event.team = source.side
	if target != null:
		event.target_id = target.id
		event.target_name = target.short_name()
	return event


static func _get_outcome(state: CombatState) -> StringName:
	var crew_alive: bool = false
	var enemy_alive: bool = false
	for actor: ActorState in state.actors:
		if actor.is_conscious():
			if actor.side == ActorState.Team.CREW:
				crew_alive = true
			else:
				enemy_alive = true
	if not crew_alive:
		return &"defeat"
	if not enemy_alive:
		return &"victory"
	return &"ongoing"
