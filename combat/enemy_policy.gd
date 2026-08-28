class_name EnemyPolicy
extends RefCounted
## Deterministic preference over the SAME legal commands used by player input.


static func choose_action(state: CombatState) -> ActionCommand:
	if state == null:
		return null
	var best: ActionCommand = null
	var best_score: float = -INF
	for command: ActionCommand in CombatRules.get_legal_actions(state, state.active_actor_id):
		var score: float = _score(state, command)
		if best == null or score > best_score or (score == best_score and _key(command) < _key(best)):
			best = command
			best_score = score
	return best


static func _key(command: ActionCommand) -> String:
	return String(command.action_id) + ":" + (String(command.target_ids[0]) if not command.target_ids.is_empty() else "")


static func _score(state: CombatState, command: ActionCommand) -> float:
	if command.action_id == &"wait":
		return -1.0
	if command.action_id == &"move":
		return -2.0
	var actor: ActorState = state.get_actor(command.actor_id)
	var target: ActorState = state.get_actor(command.target_ids[0])
	var ability: AbilityDefinition = actor.definition.get_ability(command.action_id)
	var score: float = float(CombatRules.adjusted_damage(target, ability, ability.damage_max))
	for effect: EffectDefinition in ability.effects:
		var recipient: ActorState = actor if effect.on_actor else target
		match effect.kind:
			EffectDefinition.Kind.HEAL:
				score += mini(effect.amount, recipient.definition.max_health - recipient.health)
			EffectDefinition.Kind.STRAIN:
				score += mini(effect.amount, state.balance.strain_max - recipient.strain) if effect.amount > 0 else mini(-effect.amount, recipient.strain)
			EffectDefinition.Kind.STATUS:
				if recipient.get_status(effect.status.kind) == null:
					# Protect unprotected allies, then attack while those shields last.
					score += state.balance.ai_protection_bonus if effect.status.kind == StatusDefinition.Kind.PROTECTION else state.balance.ai_status_bonus
			EffectDefinition.Kind.DISPLACE:
				var rank: int = state.get_rank(recipient.id)
				if clampi(rank + effect.amount, 1, state.get_ranks(recipient.side).size()) != rank:
					score += state.balance.ai_movement_bonus
	return score
