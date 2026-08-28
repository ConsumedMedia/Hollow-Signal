class_name CombatRules
extends RefCounted
## All gameplay mutations and damage rolls are here. No SceneTree dependency.


static func create_battle(crew: ActorDefinition, enemy: ActorDefinition) -> CombatState:
	if crew == null or enemy == null or not crew.is_valid() or not enemy.is_valid():
		return null
	var state: CombatState = CombatState.new()
	state.actors = [ActorState.new(&"crew_1", crew, ActorState.Team.CREW),
		ActorState.new(&"enemy_1", enemy, ActorState.Team.ENEMY)]
	state.active_actor_id = &"crew_1"
	return state


static func get_legal_actions(state: CombatState, actor_id: StringName) -> Array[ActionCommand]:
	var legal: Array[ActionCommand] = []
	if state == null or state.outcome != &"ongoing" or state.active_actor_id != actor_id:
		return legal
	var actor: ActorState = state.get_actor(actor_id)
	if actor == null or not actor.is_conscious():
		return legal
	var opponent: ActorState = state.get_opponent(actor)
	if opponent != null:
		var attack: ActionCommand = ActionCommand.new(actor_id, &"attack", [opponent.id], state.turn_number)
		if validate_action(state, attack).is_empty():
			legal.append(attack)
	var wait: ActionCommand = ActionCommand.new(actor_id, &"wait", [], state.turn_number)
	if validate_action(state, wait).is_empty():
		legal.append(wait)
	return legal


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
	if command.action_id != &"attack":
		return "Unknown action."
	if command.target_ids.size() != 1:
		return "Attack needs exactly one target."
	var target: ActorState = state.get_actor(command.target_ids[0])
	if target == null or target.side == actor.side or not target.is_conscious():
		return "Attack needs a conscious opponent."
	if not actor.definition.is_valid():
		return "Invalid actor definition."
	return ""


static func resolve_action(state: CombatState, command: ActionCommand, rng: RandomNumberGenerator) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	# Validate EVERYTHING before any mutation or RNG consumption.
	if rng == null or not validate_action(state, command).is_empty():
		return events
	var actor: ActorState = state.get_actor(command.actor_id)
	if command.action_id == &"attack":
		var target: ActorState = state.get_actor(command.target_ids[0])
		var rolled_damage: int = rng.randi_range(actor.definition.damage_min, actor.definition.damage_max)
		var damage: int = mini(target.health, rolled_damage)
		target.health -= damage
		var hit: CombatEvent = CombatEvent.new(&"damage", actor.id, target.id, damage)
		hit.health_after = target.health
		events.append(hit)
		if not target.is_conscious():
			events.append(CombatEvent.new(&"defeated", actor.id, target.id))
	else:
		events.append(CombatEvent.new(&"wait", actor.id))

	state.turn_number += 1
	state.outcome = _get_outcome(state)
	if state.outcome != &"ongoing":
		state.active_actor_id = &""
		var ended: CombatEvent = CombatEvent.new(&"battle_ended")
		ended.outcome = state.outcome
		events.append(ended)
		return events

	# Temporary M2 order: crew, enemy, then the next round. Initiative is M3.
	state.active_actor_id = state.get_opponent(actor).id
	if actor.side == ActorState.Team.ENEMY:
		state.round_number += 1
	var next_turn: CombatEvent = CombatEvent.new(&"turn_started", state.active_actor_id)
	next_turn.round_number = state.round_number
	events.append(next_turn)
	return events


static func _get_outcome(state: CombatState) -> StringName:
	var crew_alive: bool = false
	var enemy_alive: bool = false
	for actor: ActorState in state.actors:
		if actor.is_conscious():
			if actor.side == ActorState.Team.CREW:
				crew_alive = true
			else:
				enemy_alive = true
	# Defeat has priority if a future effect eliminates both sides at once.
	if not crew_alive:
		return &"defeat"
	if not enemy_alive:
		return &"victory"
	return &"ongoing"
