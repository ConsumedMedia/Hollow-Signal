extends RefCounted
## Rules tests run without any battle scene, animation, timer, UI, or sound.

var _checks: int = 0
var _failures: int = 0


func run() -> int:
	_test_definitions_and_instances()
	_test_initiative()
	_test_legality_and_moves()
	_test_invalid_commands()
	_test_removal_and_outcomes()
	_test_replays_and_awkward_formations()
	if "--self-test-failure" in OS.get_cmdline_user_args():
		_check(false, "Intentional test-runner failure")
	print("COMBAT RULES: %d checks, %d failures" % [_checks, _failures])
	return _failures


func _test_definitions_and_instances() -> void:
	var rng: RandomNumberGenerator = _rng(42)
	var state: CombatState = _battle(rng)
	_check(state.actors.size() == 8 and state.crew_ranks.size() == 4 and state.enemy_ranks.size() == 4, "Four actors per side, each occupying one rank")
	_check(state.get_actor(&"crew_1").definition == state.get_actor(&"crew_2").definition, "Crew instances share authored definitions")
	var before: Dictionary = _definition_snapshot(ContentCatalogue.TEST_CREW)
	_activate(state, &"enemy_1")
	CombatRules.resolve_action(state, _command(state, &"strike", &"crew_1"), rng)
	_check(state.get_actor(&"crew_1").health < 30 and state.get_actor(&"crew_2").health == 30, "Shared definitions do not share mutable health")
	_check(_definition_snapshot(ContentCatalogue.TEST_CREW) == before, "Attacks never mutate actor or ability Resources")
	_check(_battle(_rng(42)).get_actor(&"crew_1").health == 30, "A separate battle has independent health")
	var bad: ActorDefinition = ContentCatalogue.TEST_CREW.duplicate(true) as ActorDefinition
	bad.max_health = 0
	var saved_rng: int = rng.state
	_check(CombatRules.create_battle([bad], [ContentCatalogue.TEST_ENEMY], rng) == null and rng.state == saved_rng, "Invalid content rejects creation before initiative rolls")
	_check(CombatRules.create_battle([null], [], rng) == null, "Missing definition rejected")
	_check(CombatRules.create_battle([], [], null) == null, "Missing RNG rejected")
	_check(_battle(rng, 5, 1) == null, "A fifth rank is rejected")
	var ability: AbilityDefinition = ContentCatalogue.TEST_CREW.abilities[0].duplicate() as AbilityDefinition
	ability.target_ranks = [0, 5]
	_check(not ability.is_valid(), "Ability ranks must be in 1 through 4")
	ability.target_ranks = [1, 1]
	_check(not ability.is_valid(), "Duplicate authored ranks rejected")
	ability.target_ranks = [1]
	ability.damage_max = ability.damage_min - 1
	_check(not ability.is_valid(), "Reversed damage ranges rejected")
	var targets: Array[StringName] = [&"enemy_1"]
	var command: ActionCommand = ActionCommand.new(&"crew_1", &"strike", targets, 0)
	targets.clear()
	_check(command.target_ids == [&"enemy_1"], "Commands own their target list")


func _test_initiative() -> void:
	var valid: bool = true
	var ties_seen: bool = false
	var rerolls_seen: bool = false
	for seed_value: int in range(64):
		var rng: RandomNumberGenerator = _rng(seed_value)
		var state: CombatState = _battle(rng)
		var expected_rng: RandomNumberGenerator = _rng(seed_value)
		var ids: Array[StringName] = [&"crew_1", &"crew_2", &"crew_3", &"crew_4", &"enemy_1", &"enemy_2", &"enemy_3", &"enemy_4"]
		for actor_id: StringName in ids:
			var roll: int = expected_rng.randi_range(1, 6)
			valid = valid and state.initiative_rolls[actor_id] == roll
			valid = valid and state.initiative_scores[actor_id] == state.get_actor(actor_id).definition.speed + roll
		valid = valid and rng.state == expected_rng.state and state.round_order.size() == 8
		for index: int in range(1, state.round_order.size()):
			var a: StringName = state.round_order[index - 1]
			var b: StringName = state.round_order[index]
			valid = valid and state.initiative_scores[a] >= state.initiative_scores[b]
			if state.initiative_scores[a] == state.initiative_scores[b]:
				ties_seen = true
				valid = valid and String(a) < String(b)
		var previous_scores: Dictionary = state.initiative_scores.duplicate()
		var acted: Array[StringName] = []
		for turn: int in range(8):
			valid = valid and state.active_actor_id not in acted
			acted.append(state.active_actor_id)
			CombatRules.resolve_action(state, _command(state, &"wait"), rng)
		valid = valid and acted.size() == 8 and state.round_number == 2 and state.turn_number == 8
		rerolls_seen = rerolls_seen or previous_scores != state.initiative_scores
	_check(valid, "64 seeds: Speed + inclusive d6, canonical draws, descending initiative, ID ties, once per round")
	_check(ties_seen and rerolls_seen, "Tests exercise ties and fresh initiative each round")
	var rng_a: RandomNumberGenerator = _rng(99)
	var rng_b: RandomNumberGenerator = _rng(99)
	var a_state: CombatState = _battle(rng_a)
	var b_state: CombatState = _battle(rng_b)
	b_state.actors.reverse()
	b_state.crew_ranks.reverse()
	for turn: int in range(8):
		CombatRules.resolve_action(a_state, _command(a_state, &"wait"), rng_a)
		CombatRules.resolve_action(b_state, _command(b_state, &"wait"), rng_b)
	_check(a_state.round_order == b_state.round_order and a_state.initiative_scores == b_state.initiative_scores and rng_a.state == rng_b.state, "Storage and formation order do not change initiative randomness")


func _test_legality_and_moves() -> void:
	var rng: RandomNumberGenerator = _rng(7)
	var state: CombatState = _battle(rng)
	_activate(state, &"crew_2")
	var before: Dictionary = _snapshot(state, rng)
	var legal: Array[ActionCommand] = CombatRules.get_legal_actions(state, &"crew_2")
	_check(_has(legal, &"strike", &"enemy_1") and _has(legal, &"strike", &"enemy_2") and not _has(legal, &"strike", &"enemy_3"), "Close strike targets enemy ranks 1 and 2 only")
	_check(not _has(legal, &"shot") and _has(legal, &"wait"), "Front actor cannot use rear attack but can always Wait")
	_check(_has(legal, &"move", &"crew_1") and _has(legal, &"move", &"crew_3") and not _has(legal, &"move", &"crew_4"), "Only adjacent allies are legal swaps")
	_check(CombatRules.get_legal_actions(state, &"enemy_1").is_empty() and CombatRules.get_legal_actions(state, &"missing").is_empty(), "Inactive or unknown actors have no legal actions")
	_check(_snapshot(state, rng) == before, "Legal-action queries leave state, content and RNG unchanged")
	var order_before: Array[StringName] = state.round_order.duplicate()
	var rng_before: int = rng.state
	var events: Array[CombatEvent] = CombatRules.resolve_action(state, _command(state, &"move", &"crew_3"), rng)
	_check(state.crew_ranks == [&"crew_1", &"crew_3", &"crew_2", &"crew_4"], "Move swaps rank 2 and rank 3")
	_check(state.round_order == order_before and state.turn_number == 1 and state.active_actor_id != &"crew_2", "Move consumes a turn without changing the queue")
	_check(rng.state == rng_before and state.get_actor(&"crew_2").health == 30, "Move itself changes no health or randomness")
	_check(CombatRules.ability_reason(state, &"crew_2", &"strike").contains("current rank 3") and CombatRules.ability_reason(state, &"crew_2", &"shot").is_empty(), "Swapped actor's ability availability changes immediately")
	_check(CombatRules.ability_reason(state, &"crew_3", &"strike").is_empty(), "Swapped ally gets its new rank requirements immediately")
	_check(events[0].kind == &"moved" and events[0].source_rank == 2 and events[0].target_rank == 3, "Move emits original ranks for presentation")
	var saved_formation: Array[StringName] = events[0].rank_ids.duplicate()
	var acted: Array[StringName] = [&"crew_2"]
	var wait_unchanged: bool = true
	while state.round_number == 1:
		_check(state.active_actor_id not in acted, "No second action after a swap")
		acted.append(state.active_actor_id)
		var before_wait: Dictionary = _snapshot(state, rng)
		CombatRules.resolve_action(state, _command(state, &"wait"), rng)
		wait_unchanged = wait_unchanged and _snapshot(state, rng).actors == before_wait.actors
		if state.round_number == 1:
			wait_unchanged = wait_unchanged and rng.state == before_wait.rng
	_check(wait_unchanged, "Wait never changes health; only round-boundary initiative consumes RNG")
	_check(acted.size() == 8, "Swapping does not steal the ally's turn")
	state.crew_ranks.reverse()
	_check(events[0].rank_ids == saved_formation, "Movement event formation is a value snapshot")
	_activate(state, &"crew_3")
	# Current crew_3 rank is 3 after reversing the swapped formation.
	legal = CombatRules.get_legal_actions(state, &"crew_3")
	_check(_has(legal, &"shot", &"enemy_4") and not _has(legal, &"strike"), "Rear attack can target the last enemy rank")


func _test_invalid_commands() -> void:
	var rng: RandomNumberGenerator = _rng(19)
	var state: CombatState = _battle(rng)
	_activate(state, &"crew_1")
	var invalid: Array[ActionCommand] = [
		null, ActionCommand.new(&"missing", &"wait", [], 0),
		ActionCommand.new(&"enemy_1", &"strike", [&"crew_1"], 0),
		_command(state, &"unknown", &"enemy_1"), _command(state, &"strike"),
		ActionCommand.new(&"crew_1", &"strike", [&"enemy_1", &"enemy_2"], 0),
		_command(state, &"strike", &"missing"), _command(state, &"strike", &"crew_2"),
		_command(state, &"strike", &"enemy_4"), _command(state, &"shot", &"enemy_1"),
		_command(state, &"wait", &"enemy_1"), _command(state, &"move", &"crew_1"),
		_command(state, &"move", &"crew_3"), _command(state, &"move", &"enemy_1"),
		ActionCommand.new(&"crew_1", &"wait", [], 1)]
	for index: int in range(invalid.size()):
		_assert_rejected(state, invalid[index], rng, "Invalid command %d" % (index + 1))
	var before: Dictionary = _snapshot(state, rng)
	_check(CombatRules.resolve_action(state, _command(state, &"wait"), null).is_empty() and _snapshot(state, rng) == before, "Missing RNG cannot partially resolve an action")
	_check(not CombatRules.validate_action(null, invalid[1]).is_empty() and CombatRules.resolve_action(null, invalid[1], rng).is_empty(), "Missing state rejected safely")
	var stale: ActionCommand = _command(state, &"move", &"crew_2")
	CombatRules.resolve_action(state, stale, rng)
	_assert_rejected(state, stale, rng, "Immediate duplicate")
	while state.round_number == 1:
		CombatRules.resolve_action(state, _command(state, &"wait"), rng)
	_activate(state, &"crew_1")
	_assert_rejected(state, stale, rng, "Stale command on a later turn")
	state.get_actor(&"crew_1").health = 0
	_assert_rejected(state, _command(state, &"wait"), rng, "Defeated actor")
	_check(CombatRules.get_legal_actions(state, &"crew_1").is_empty(), "Defeated actor receives no commands")


func _test_removal_and_outcomes() -> void:
	var rng: RandomNumberGenerator = _rng(11)
	var state: CombatState = _battle(rng)
	_activate(state, &"crew_1")
	state.get_actor(&"enemy_1").health = 1
	var events: Array[CombatEvent] = CombatRules.resolve_action(state, _command(state, &"strike", &"enemy_1"), rng)
	_check(events[0].amount == 1 and events[0].health_after == 0, "Overkill clamps to remaining HP")
	_check(events[1].kind == &"defeated" and events[2].kind == &"ranks_compacted", "Lethal damage emits defeat then rank compaction")
	_check(state.get_actor(&"enemy_1") == null and state.enemy_ranks == [&"enemy_2", &"enemy_3", &"enemy_4"], "Defeated actor removed and ranks close up")
	_check(state.get_rank(&"enemy_3") == 2 and CombatRules.ability_reason(state, &"enemy_3", &"strike").is_empty(), "Compaction changes a survivor's available attacks")
	_check(events[1].target_name == "E1" and events[1].target_rank == 1, "Removed actor still has a presentation snapshot")
	var dead_acted: bool = false
	while state.round_number == 1:
		dead_acted = dead_acted or state.active_actor_id == &"enemy_1"
		CombatRules.resolve_action(state, _command(state, &"wait"), rng)
	_check(not dead_acted and &"enemy_1" not in state.round_order, "Removed actor skipped in current and future round queues")
	_assert_rejected(state, ActionCommand.new(state.active_actor_id, &"strike", [&"enemy_1"], state.turn_number), rng, "Removed target")
	state = _battle(rng, 1, 1)
	_activate(state, &"crew_1")
	state.get_actor(&"enemy_1").health = 1
	events = CombatRules.resolve_action(state, _command(state, &"strike", &"enemy_1"), rng)
	_check(state.outcome == &"victory" and state.active_actor_id.is_empty() and events[-1].outcome == &"victory", "Final enemy removal ends in victory")
	_assert_rejected(state, _command(state, &"wait"), rng, "Command after victory")
	_check(CombatRules.get_legal_actions(state, &"crew_1").is_empty(), "No actions after victory")
	state = _battle(rng, 1, 1)
	_activate(state, &"enemy_1")
	state.get_actor(&"crew_1").health = 1
	events = CombatRules.resolve_action(state, _command(state, &"strike", &"crew_1"), rng)
	_check(state.outcome == &"defeat" and state.crew_ranks.is_empty() and events[-1].outcome == &"defeat", "Final crew removal ends in defeat")
	_assert_rejected(state, _command(state, &"wait"), rng, "Command after defeat")
	var saved_rng: int = rng.state
	_check(_battle(rng, 0, 4).outcome == &"defeat" and _battle(rng, 4, 0).outcome == &"victory" and _battle(rng, 0, 0).outcome == &"defeat", "Empty sides are terminal; simultaneous absence is defeat")
	_check(rng.state == saved_rng, "Terminal battle creation needs no random roll")


func _test_replays_and_awkward_formations() -> void:
	var stable: bool = true
	var wins: bool = true
	var losses: bool = true
	var varied: bool = false
	var first: Dictionary = _simulate(0, false)
	for seed_value: int in range(64):
		var attacks: Dictionary = _simulate(seed_value, false)
		var waits: Dictionary = _simulate(seed_value, true)
		stable = stable and attacks == _simulate(seed_value, false) and waits == _simulate(seed_value, true)
		wins = wins and attacks.final.outcome == &"victory"
		losses = losses and waits.final.outcome == &"defeat"
		varied = varied or attacks != first
	_check(stable, "64 seeds: attacks/moves/waits reproduce events, formations, initiative, health and RNG")
	_check(varied, "Different seeds produce different results")
	_check(wins and losses, "64 seeds: full parties can win by attacking and lose by waiting")
	var rng: RandomNumberGenerator = _rng(1729)
	var stranded: ActorDefinition = ContentCatalogue.TEST_CREW.duplicate(true) as ActorDefinition
	stranded.abilities = [stranded.abilities[1]]
	var state: CombatState = CombatRules.create_battle([stranded], [stranded], rng)
	var progresses: bool = true
	for action: int in range(20):
		var legal: Array[ActionCommand] = CombatRules.get_legal_actions(state, state.active_actor_id)
		progresses = progresses and legal.size() == 1 and legal[0].action_id == &"wait"
		CombatRules.resolve_action(state, legal[0], rng)
	_check(progresses and state.round_number == 11, "Stranded rear-only actors can Wait for ten rounds without a softlock")
	state = _battle(rng)
	var seen: Array[StringName] = []
	var duplicate: bool = false
	for action: int in range(32):
		if seen.size() == 8:
			seen.clear()
		duplicate = duplicate or state.active_actor_id in seen
		seen.append(state.active_actor_id)
		var legal: Array[ActionCommand] = CombatRules.get_legal_actions(state, state.active_actor_id)
		var command: ActionCommand = legal[-1]
		for candidate: ActionCommand in legal:
			if candidate.action_id == &"move":
				command = candidate
				break
		CombatRules.resolve_action(state, command, rng)
	_check(not duplicate and state.round_number == 5 and state.actors.size() == 8, "Four rounds of swaps preserve exactly one turn per actor")


func _simulate(seed_value: int, crew_waits: bool) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var state: CombatState = _battle(rng)
	var transcript: Array[Dictionary] = []
	for action_index: int in range(1000):
		if state.outcome != &"ongoing":
			break
		var actor: ActorState = state.get_actor(state.active_actor_id)
		var legal: Array[ActionCommand] = CombatRules.get_legal_actions(state, actor.id)
		var command: ActionCommand = legal[-1]
		if not crew_waits or actor.side == ActorState.Team.ENEMY:
			command = legal[0]
			if not crew_waits and action_index % 7 == 0:
				for candidate: ActionCommand in legal:
					if candidate.action_id == &"move":
						command = candidate
						break
		for event: CombatEvent in CombatRules.resolve_action(state, command, rng):
			transcript.append({"kind": event.kind, "source": event.source_id, "target": event.target_id,
				"amount": event.amount, "health": event.health_after, "round": event.round_number,
				"outcome": event.outcome, "ranks": event.rank_ids.duplicate(), "from": event.source_rank, "to": event.target_rank})
	return {"final": _snapshot(state, rng), "events": transcript}


func _battle(rng: RandomNumberGenerator, crew_count: int = 4, enemy_count: int = 4) -> CombatState:
	var crew: Array[ActorDefinition] = []
	var enemy: Array[ActorDefinition] = []
	for index: int in range(crew_count):
		crew.append(ContentCatalogue.TEST_CREW)
	for index: int in range(enemy_count):
		enemy.append(ContentCatalogue.TEST_ENEMY)
	return CombatRules.create_battle(crew, enemy, rng)


func _activate(state: CombatState, actor_id: StringName) -> void:
	# Targeted tests use a valid queue fixture; replay/initiative tests never do.
	state.round_order.erase(actor_id)
	state.round_order.push_front(actor_id)
	state.turn_cursor = 0
	state.active_actor_id = actor_id


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _command(state: CombatState, action: StringName, target: StringName = &"") -> ActionCommand:
	var targets: Array[StringName] = []
	if not target.is_empty():
		targets.append(target)
	return ActionCommand.new(state.active_actor_id, action, targets, state.turn_number)


func _has(commands: Array[ActionCommand], action: StringName, target: StringName = &"") -> bool:
	for command: ActionCommand in commands:
		if command.action_id == action and (target.is_empty() or target in command.target_ids):
			return true
	return false


func _assert_rejected(state: CombatState, command: ActionCommand, rng: RandomNumberGenerator, label: String) -> void:
	var before: Dictionary = _snapshot(state, rng)
	var reason: String = CombatRules.validate_action(state, command)
	var events: Array[CombatEvent] = CombatRules.resolve_action(state, command, rng)
	_check(not reason.is_empty() and events.is_empty() and _snapshot(state, rng) == before, "%s: no state/content/RNG mutation" % label)


func _snapshot(state: CombatState, rng: RandomNumberGenerator) -> Dictionary:
	var actors: Array[Dictionary] = []
	for actor: ActorState in state.actors:
		actors.append({"id": actor.id, "side": actor.side, "health": actor.health, "definition": _definition_snapshot(actor.definition)})
	return {"actors": actors, "active": state.active_actor_id, "round": state.round_number,
		"turn": state.turn_number, "outcome": state.outcome, "rng": rng.state,
		"crew": state.crew_ranks.duplicate(), "enemy": state.enemy_ranks.duplicate(),
		"order": state.round_order.duplicate(), "cursor": state.turn_cursor,
		"rolls": state.initiative_rolls.duplicate(), "scores": state.initiative_scores.duplicate()}


func _definition_snapshot(definition: ActorDefinition) -> Dictionary:
	var abilities: Array[Dictionary] = []
	for ability: AbilityDefinition in definition.abilities:
		abilities.append({"id": ability.id, "name": ability.display_name, "actor_ranks": ability.actor_ranks.duplicate(),
			"target_ranks": ability.target_ranks.duplicate(), "min": ability.damage_min, "max": ability.damage_max})
	return {"id": definition.id, "name": definition.display_name, "max_health": definition.max_health,
		"speed": definition.speed, "abilities": abilities}


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		printerr("FAIL: ", description)
