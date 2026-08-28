class_name CombatRules
extends RefCounted
## All gameplay mutations and random rolls are here. No SceneTree dependency.

const MAX_RANKS: int = 4
const BALANCE: CombatBalance = preload("res://content/balance.tres")


static func create_battle(crew: Array[ActorDefinition], enemy: Array[ActorDefinition],
		rng: RandomNumberGenerator, expedition: ExpeditionState = null) -> CombatState:
	if rng == null or crew.size() > MAX_RANKS or enemy.size() > MAX_RANKS or not BALANCE.is_valid():
		return null
	for definition: ActorDefinition in crew + enemy:
		if definition == null or not definition.is_valid():
			return null
	var state: CombatState = CombatState.new()
	state.balance = BALANCE
	if expedition == null:
		expedition = new_expedition(crew)
	if expedition.failed or expedition.battle_active:
		return null
	state.expedition = expedition
	state.encounter_room = expedition.encounter_room
	for crew_id: StringName in expedition.crew_ranks:
		var member: CrewState = expedition.get_crew(crew_id)
		if member.dead:
			continue
		var actor: ActorState = ActorState.new(member.id, member.definition, ActorState.Team.CREW)
		actor.health = member.health
		actor.strain = member.strain
		actor.shaken = member.shaken
		state.actors.append(actor)
		state.crew_ranks.append(actor.id)
	for index: int in range(enemy.size()):
		var actor: ActorState = ActorState.new(StringName("enemy_%d" % (index + 1)), enemy[index], ActorState.Team.ENEMY)
		state.actors.append(actor)
		state.enemy_ranks.append(actor.id)
	expedition.battle_active = true
	var initial_events: Array[CombatEvent] = []
	if not _finish_outcome(state, initial_events):
		_start_round(state, rng)
		state.turn_cursor = -1
		_advance_turn(state, rng, initial_events)
	_sync_crew(state)
	return state


static func new_expedition(crew: Array[ActorDefinition]) -> ExpeditionState:
	var expedition: ExpeditionState = ExpeditionState.new()
	expedition.power = BALANCE.starting_power
	for index: int in range(crew.size()):
		var member: CrewState = CrewState.new(StringName("crew_%d" % (index + 1)), crew[index])
		expedition.crew.append(member)
		expedition.crew_ranks.append(member.id)
	return expedition


static func room_strain(power: int) -> int:
	if power >= BALANCE.power_safe_threshold:
		return 0
	return BALANCE.medium_power_strain if power >= BALANCE.power_low_threshold else BALANCE.low_power_strain


static func traverse_test_corridor(expedition: ExpeditionState) -> bool:
	# Rules hook for M6, exposed only by the between-battle test control in M5.
	if expedition == null or expedition.failed or expedition.battle_active:
		return false
	expedition.power = maxi(0, expedition.power - BALANCE.corridor_power_cost)
	for member: CrewState in expedition.crew:
		if not member.dead:
			member.strain = clampi(member.strain + room_strain(expedition.power), 0, BALANCE.strain_max)
			member.shaken = shaken_after(member.strain, member.shaken)
	return true


static func shaken_after(strain: int, was_shaken: bool) -> bool:
	if strain >= BALANCE.shaken_threshold:
		return true
	return was_shaken and strain >= BALANCE.shaken_clear_below


static func _sync_crew(state: CombatState) -> void:
	state.expedition.crew_ranks = state.crew_ranks.duplicate()
	for actor: ActorState in state.actors:
		if actor.side == ActorState.Team.CREW:
			var member: CrewState = state.expedition.get_crew(actor.id)
			member.health = actor.health
			member.strain = actor.strain
			member.shaken = actor.shaken
			member.dead = actor.dead


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
			var charged: ActionCommand = ActionCommand.new(actor_id, ability.id, [target.id], state.turn_number, true)
			if validate_action(state, charged).is_empty():
				legal.append(charged)
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
		return "Downed or dead crew cannot act."
	var ability: AbilityDefinition = actor.definition.get_ability(ability_id)
	if ability == null:
		return "Unknown ability."
	if not ability.is_valid():
		return "Invalid ability definition."
	if ability.max_uses > 0 and actor.uses.get(ability.id, 0) >= ability.max_uses:
		return "No uses left this battle."
	var rank: int = state.get_rank(actor_id)
	if rank not in ability.actor_ranks:
		return "Needs actor ranks %s; current rank %d." % [rank_text(ability.actor_ranks), rank]
	for target: ActorState in state.actors:
		if _target_reason(state, actor, target, ability).is_empty():
			return ""
	return "No eligible %s in ranks %s (check HP, strain or space)." % [
		"ally" if ability.target_team == AbilityDefinition.TargetTeam.ALLY else "enemy", rank_text(ability.target_ranks)]


static func _target_reason(state: CombatState, actor: ActorState, target: ActorState, ability: AbilityDefinition) -> String:
	if target.dead:
		return "Target is dead."
	var same_team: bool = actor.side == target.side
	if same_team != (ability.target_team == AbilityDefinition.TargetTeam.ALLY):
		return "Wrong target team."
	if actor.id == target.id and not ability.allow_self:
		return "Choose another ally."
	if state.get_rank(target.id) not in ability.target_ranks:
		return "Target needs ranks %s." % rank_text(ability.target_ranks)
	if ability.damage_max == 0 and ability.effects.size() == 1:
		var effect: EffectDefinition = ability.effects[0]
		var recipient: ActorState = actor if effect.on_actor else target
		if effect.kind == EffectDefinition.Kind.HEAL and recipient.health >= recipient.definition.max_health:
			return "Target already has full health."
		if effect.kind == EffectDefinition.Kind.STRAIN and effect.amount < 0 and recipient.strain == 0:
			return "Target has no strain."
		if effect.kind == EffectDefinition.Kind.DISPLACE and _destination(state, recipient, effect.amount) == state.get_rank(recipient.id):
			return "No room to move the target."
	return ""


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
		return "A downed or dead actor cannot act."
	if command.overcharge:
		var charged_ability: AbilityDefinition = actor.definition.get_ability(command.action_id)
		if actor.side != ActorState.Team.CREW or charged_ability == null or charged_ability.damage_max <= 0:
			return "Overcharge is only for damaging crew abilities."
		if state.expedition.power < state.balance.overcharge_cost:
			return "Overcharge needs %d power." % state.balance.overcharge_cost
	if command.action_id == &"wait":
		return "Wait does not take a target." if not command.target_ids.is_empty() else ""
	if command.target_ids.size() != 1:
		return "Choose exactly one target."
	var target: ActorState = state.get_actor(command.target_ids[0])
	if target == null or target.dead:
		return "Target is missing or dead."
	if command.action_id == &"move":
		if target.side != actor.side or absi(state.get_rank(actor.id) - state.get_rank(target.id)) != 1:
			return "Move swaps with an adjacent ally only."
		return ""
	var reason: String = ability_reason(state, actor.id, command.action_id)
	if not reason.is_empty():
		return reason
	var ability: AbilityDefinition = actor.definition.get_ability(command.action_id)
	return _target_reason(state, actor, target, ability)


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
		actor.uses[ability.id] = actor.uses.get(ability.id, 0) + 1
		if command.overcharge:
			state.expedition.power -= state.balance.overcharge_cost
			var spent: CombatEvent = _event(&"power_spent", actor)
			spent.amount = state.balance.overcharge_cost
			spent.power_after = state.expedition.power
			events.append(spent)
		if ability.damage_max > 0:
			var rolled: int = rng.randi_range(ability.damage_min, ability.damage_max)
			_damage(state, actor, target, adjusted_damage(target, ability, rolled, actor, command.overcharge), events)
		for effect: EffectDefinition in ability.effects:
			var recipient: ActorState = actor if effect.on_actor else target
			if state.get_actor(recipient.id) != null:
				_apply_effect(state, actor, recipient, effect, events)
		for event: CombatEvent in events:
			event.ability_name = ability.display_name

	state.turn_number += 1
	if _finish_outcome(state, events):
		_sync_crew(state)
		return events
	_advance_turn(state, rng, events)
	_sync_crew(state)
	return events


static func adjusted_damage(target: ActorState, ability: AbilityDefinition, rolled: int,
		source: ActorState = null, overcharge: bool = false) -> int:
	var multiplier: float = ability.exposed_multiplier if target.get_status(StatusDefinition.Kind.EXPOSE) != null else 1.0
	if source != null and source.shaken:
		multiplier *= BALANCE.shaken_damage_multiplier
	if overcharge:
		multiplier *= BALANCE.overcharge_multiplier
	var protection: StatusState = target.get_status(StatusDefinition.Kind.PROTECTION)
	if protection != null:
		multiplier *= 1.0 - protection.definition.magnitude / 100.0
	return maxi(0, floori(rolled * multiplier))


static func _damage(state: CombatState, source: ActorState, target: ActorState, amount: int,
		events: Array[CombatEvent], dot: StatusState = null) -> void:
	var was_downed: bool = target.is_downed()
	var damage: int = mini(target.health, amount)
	target.health -= damage
	var hit: CombatEvent = _event(&"damage" if dot == null else &"dot_damage", source, target)
	if dot != null:
		hit.source_id = dot.source_id
		hit.source_name = dot.source_name
		hit.status_name = dot.definition.display_name
	hit.amount = damage
	hit.health_after = target.health
	events.append(hit)
	if amount <= 0:
		return
	if was_downed or (target.side == ActorState.Team.ENEMY and target.health == 0):
		_kill(state, source, target, events, hit)
	elif target.is_downed():
		events.append(_event(&"downed", source, target))


static func _kill(state: CombatState, source: ActorState, target: ActorState,
		events: Array[CombatEvent], hit: CombatEvent = null) -> void:
	target.dead = true
	target.health = 0
	if target.side == ActorState.Team.CREW:
		var member: CrewState = state.expedition.get_crew(target.id)
		member.dead = true
		member.health = 0
		member.strain = target.strain
		member.shaken = target.shaken
	var defeated: CombatEvent = _event(&"died" if target.side == ActorState.Team.CREW else &"defeated", source, target)
	if hit != null:
		defeated.source_id = hit.source_id
		defeated.source_name = hit.source_name
	defeated.target_rank = state.get_rank(target.id)
	events.append(defeated)
	state.get_ranks(target.side).erase(target.id)
	state.actors.erase(target)
	var compacted: CombatEvent = _event(&"ranks_compacted", source)
	compacted.team = target.side
	compacted.rank_ids = state.get_ranks(target.side).duplicate()
	events.append(compacted)


static func _apply_effect(state: CombatState, source: ActorState, target: ActorState,
		effect: EffectDefinition, events: Array[CombatEvent]) -> void:
	match effect.kind:
		EffectDefinition.Kind.HEAL:
			var was_downed: bool = target.is_downed()
			var healed: CombatEvent = _event(&"healed", source, target)
			healed.amount = mini(effect.amount, target.definition.max_health - target.health)
			target.health += healed.amount
			healed.health_after = target.health
			events.append(healed)
			if was_downed and target.is_conscious():
				events.append(_event(&"revived", source, target))
		EffectDefinition.Kind.STRAIN:
			var changed: CombatEvent = _event(&"strain_changed", source, target)
			var next_strain: int = clampi(target.strain + effect.amount, 0, state.balance.strain_max)
			changed.amount = next_strain - target.strain
			target.strain = next_strain
			changed.strain_after = next_strain
			events.append(changed)
			var next_shaken: bool = shaken_after(target.strain, target.shaken)
			if target.side == ActorState.Team.CREW and next_shaken != target.shaken:
				target.shaken = next_shaken
				events.append(_event(&"shaken" if next_shaken else &"shaken_cleared", source, target))
		EffectDefinition.Kind.STATUS:
			# One instance per kind: replace/refresh, never add stacks or durations.
			var previous: StatusState = target.get_status(effect.status.kind)
			if previous != null:
				target.statuses.erase(previous)
			target.statuses.append(StatusState.new(effect.status, source))
			var applied: CombatEvent = _event(&"status_applied", source, target)
			applied.status_name = effect.status.display_name
			applied.duration = effect.status.duration
			events.append(applied)
		EffectDefinition.Kind.DISPLACE:
			var moved: CombatEvent = _event(&"displaced", source, target)
			moved.source_rank = state.get_rank(target.id)
			moved.target_rank = _destination(state, target, effect.amount)
			var ranks: Array[StringName] = state.get_ranks(target.side)
			ranks.erase(target.id)
			ranks.insert(moved.target_rank - 1, target.id)
			moved.rank_ids = ranks.duplicate()
			moved.team = target.side
			events.append(moved)


static func _destination(state: CombatState, target: ActorState, distance: int) -> int:
	return clampi(state.get_rank(target.id) + distance, 1, state.get_ranks(target.side).size())


static func _start_turn_effects(state: CombatState, actor: ActorState, events: Array[CombatEvent]) -> void:
	# DOT ticks before any selection; ordinary statuses expire before selection too.
	var dot: StatusState = actor.get_status(StatusDefinition.Kind.DAMAGE_OVER_TIME)
	if dot != null:
		_damage(state, actor, actor, dot.definition.magnitude, events, dot)
	if actor.dead:
		return
	for status: StatusState in actor.statuses.duplicate():
		status.remaining -= 1
		if status.remaining == 0:
			actor.statuses.erase(status)
			var expired: CombatEvent = _event(&"status_expired", actor, actor)
			expired.status_name = status.definition.display_name
			events.append(expired)


static func _finish_outcome(state: CombatState, events: Array[CombatEvent]) -> bool:
	state.outcome = _get_outcome(state)
	if state.outcome == &"ongoing":
		return false
	state.expedition.battle_active = false
	if state.outcome == &"defeat":
		state.expedition.failed = true
		for actor: ActorState in state.actors.duplicate():
			if actor.side == ActorState.Team.CREW:
				_kill(state, actor, actor, events)
	else:
		for actor: ActorState in state.actors:
			if actor.is_downed():
				actor.health = mini(actor.definition.max_health, state.balance.victory_recovery_health)
				var recovered: CombatEvent = _event(&"recovered", actor, actor)
				recovered.health_after = actor.health
				events.append(recovered)
	state.active_actor_id = &""
	var ended: CombatEvent = CombatEvent.new(&"battle_ended")
	ended.outcome = state.outcome
	events.append(ended)
	return true


static func _start_round(state: CombatState, rng: RandomNumberGenerator) -> void:
	state.round_order.clear()
	state.initiative_rolls.clear()
	state.initiative_scores.clear()
	for actor: ActorState in state.actors:
		if not actor.dead:
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
	while state.outcome == &"ongoing":
		state.turn_cursor += 1
		if state.turn_cursor >= state.round_order.size():
			state.round_number += 1
			_start_round(state, rng)
			var round_event: CombatEvent = CombatEvent.new(&"round_started")
			round_event.round_number = state.round_number
			round_event.rank_ids = state.round_order.duplicate()
			events.append(round_event)
		var actor: ActorState = state.get_actor(state.round_order[state.turn_cursor])
		if actor == null or actor.dead:
			continue
		state.active_actor_id = actor.id
		_start_turn_effects(state, actor, events)
		if not actor.is_conscious():
			state.turn_number += 1
		if _finish_outcome(state, events):
			return
		if not actor.is_conscious():
			continue
		var next_turn: CombatEvent = _event(&"turn_started", actor)
		next_turn.round_number = state.round_number
		events.append(next_turn)
		return


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
