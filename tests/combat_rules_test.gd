extends RefCounted
## Rules tests run without loading any scene, animation, UI, timer, or sound.

var _checks: int = 0
var _failures: int = 0


func run() -> int:
	_test_definitions_and_instances()
	_test_legality_and_turns()
	_test_invalid_commands()
	_test_terminal_outcomes()
	_test_replays()
	if "--self-test-failure" in OS.get_cmdline_user_args():
		_check(false, "Intentional test-runner failure")
	print("COMBAT RULES: %d checks, %d failures" % [_checks, _failures])
	return _failures


func _test_definitions_and_instances() -> void:
	_check(ContentCatalogue.TEST_CREW.is_valid() and ContentCatalogue.TEST_ENEMY.is_valid(), "Explicit catalogue loads valid authored Resources")
	var state: CombatState = CombatRules.create_battle(ContentCatalogue.TEST_CREW, ContentCatalogue.TEST_CREW)
	var another: CombatState = _new_battle()
	var definition_before: Dictionary = _definition_snapshot(ContentCatalogue.TEST_CREW)
	var rng: RandomNumberGenerator = _rng(42)
	CombatRules.resolve_action(state, _command(state, &"attack"), rng)
	_check(state.actors[0].definition == state.actors[1].definition, "Two instances can share one authored definition")
	_check(state.actors[0].health == ContentCatalogue.TEST_CREW.max_health and state.actors[1].health < state.actors[0].health, "Shared definition does not share mutable health")
	_check(another.actors[0].health == ContentCatalogue.TEST_CREW.max_health, "A separate battle's crew health is unchanged")
	_check(_definition_snapshot(ContentCatalogue.TEST_CREW) == definition_before, "Resolving damage never mutates the authored Resource")
	var invalid: ActorDefinition = ContentCatalogue.TEST_CREW.duplicate() as ActorDefinition
	invalid.damage_max = invalid.damage_min - 1
	_check(CombatRules.create_battle(invalid, ContentCatalogue.TEST_ENEMY) == null, "Reversed damage range rejects battle creation")
	invalid = ContentCatalogue.TEST_CREW.duplicate() as ActorDefinition
	invalid.max_health = 0
	_check(CombatRules.create_battle(invalid, ContentCatalogue.TEST_ENEMY) == null, "Nonpositive authored health rejects battle creation")
	_check(CombatRules.create_battle(null, ContentCatalogue.TEST_ENEMY) == null, "Missing definition rejects battle creation")


func _test_legality_and_turns() -> void:
	var state: CombatState = _new_battle()
	var rng: RandomNumberGenerator = _rng(1729)
	var before: Dictionary = _snapshot(state, rng)
	var legal: Array[ActionCommand] = CombatRules.get_legal_actions(state, &"crew_1")
	_check(legal.size() == 2 and legal[0].action_id == &"attack" and legal[1].action_id == &"wait", "Active crew has Attack and Wait")
	_check(CombatRules.get_legal_actions(state, &"enemy_1").is_empty() and CombatRules.get_legal_actions(state, &"unknown").is_empty(), "Inactive and unknown actors have no legal actions")
	_check(_snapshot(state, rng) == before, "Legal-action queries are read-only")
	var events: Array[CombatEvent] = CombatRules.resolve_action(state, legal[1], rng)
	_check(state.actors[0].health == 30 and state.actors[1].health == 20, "Wait neither damages nor heals")
	_check(rng.state == before.rng, "Wait consumes no randomness")
	_check(state.active_actor_id == &"enemy_1" and state.turn_number == 1 and state.round_number == 1, "Wait consumes exactly one crew turn")
	_check(_kinds(events) == [&"wait", &"turn_started"], "Wait returns ordered action and next-turn events")
	var enemy_command: ActionCommand = _command(state, &"attack")
	_check(CombatRules.validate_action(state, enemy_command).is_empty(), "Enemy uses the same validation interface")
	events = CombatRules.resolve_action(state, enemy_command, rng)
	_check(events[0].amount >= 4 and events[0].amount <= 6 and state.actors[0].health == 30 - events[0].amount, "Enemy attack always hits within its authored damage range")
	_check(state.active_actor_id == &"crew_1" and state.turn_number == 2 and state.round_number == 2, "Enemy action completes the round and returns control to crew")
	_check(events[1].kind == &"turn_started" and events[1].round_number == 2, "Turn event records the new round")
	var recorded_health: int = events[0].health_after
	state.actors[0].health = 1
	_check(events[0].health_after == recorded_health, "Event health is a value snapshot, not a live reference")
	var targets: Array[StringName] = [&"enemy_1"]
	var command: ActionCommand = ActionCommand.new(&"crew_1", &"attack", targets, 2)
	targets.clear()
	_check(command.target_ids == [&"enemy_1"], "Command owns its target list")


func _test_invalid_commands() -> void:
	var state: CombatState = _new_battle()
	var rng: RandomNumberGenerator = _rng(7)
	var invalid: Array[ActionCommand] = [
		null,
		ActionCommand.new(&"missing", &"attack", [&"enemy_1"], 0),
		ActionCommand.new(&"enemy_1", &"attack", [&"crew_1"], 0),
		ActionCommand.new(&"crew_1", &"unknown", [], 0),
		ActionCommand.new(&"crew_1", &"attack", [], 0),
		ActionCommand.new(&"crew_1", &"attack", [&"enemy_1", &"enemy_1"], 0),
		ActionCommand.new(&"crew_1", &"attack", [&"crew_1"], 0),
		ActionCommand.new(&"crew_1", &"attack", [&"missing"], 0),
		ActionCommand.new(&"crew_1", &"wait", [&"enemy_1"], 0),
		ActionCommand.new(&"crew_1", &"attack", [&"enemy_1"], -1),
		ActionCommand.new(&"crew_1", &"attack", [&"enemy_1"], 1),
	]
	for index: int in range(invalid.size()):
		_assert_rejected(state, invalid[index], rng, "Malformed command %d" % index)
	var before: Dictionary = _snapshot(state, rng)
	_check(CombatRules.resolve_action(state, _command(state, &"attack"), null).is_empty() and _snapshot(state, rng) == before, "Missing RNG cannot partially resolve an action")
	_check(not CombatRules.validate_action(null, invalid[1]).is_empty() and CombatRules.resolve_action(null, invalid[1], rng).is_empty(), "Missing state is rejected safely")
	state.actors[1].health = 0
	_assert_rejected(state, ActionCommand.new(&"crew_1", &"attack", [&"enemy_1"], 0), rng, "Defeated target")
	state.actors[0].health = 0
	_assert_rejected(state, ActionCommand.new(&"crew_1", &"wait", [], 0), rng, "Defeated actor")
	_check(CombatRules.get_legal_actions(state, &"crew_1").is_empty(), "Defeated actor cannot receive legal actions")
	state = _new_battle()
	var stale: ActionCommand = _command(state, &"attack")
	CombatRules.resolve_action(state, stale, rng)
	_assert_rejected(state, stale, rng, "Immediate duplicate attack")
	CombatRules.resolve_action(state, _command(state, &"wait"), rng)
	_assert_rejected(state, stale, rng, "Old attack after the crew becomes active again")


func _test_terminal_outcomes() -> void:
	var state: CombatState = _new_battle()
	var rng: RandomNumberGenerator = _rng(1729)
	state.actors[1].health = 1
	var events: Array[CombatEvent] = CombatRules.resolve_action(state, _command(state, &"attack"), rng)
	_check(state.outcome == &"victory" and state.active_actor_id.is_empty(), "Lethal crew attack immediately ends in victory")
	_check(events[0].amount == 1 and state.actors[1].health == 0, "Overkill is clamped to remaining health")
	_check(_kinds(events) == [&"damage", &"defeated", &"battle_ended"] and events[2].outcome == &"victory", "Lethal action emits damage, defeat, outcome; no defeated enemy turn")
	_assert_rejected(state, ActionCommand.new(&"crew_1", &"wait", [], state.turn_number), rng, "Action after victory")
	_check(CombatRules.get_legal_actions(state, &"crew_1").is_empty(), "No actions after victory")
	state = _new_battle()
	CombatRules.resolve_action(state, _command(state, &"wait"), rng)
	state.actors[0].health = 1
	events = CombatRules.resolve_action(state, _command(state, &"attack"), rng)
	_check(state.outcome == &"defeat" and state.active_actor_id.is_empty() and state.actors[0].health == 0, "Lethal enemy attack ends in defeat")
	_check(events[-1].outcome == &"defeat", "Defeat event reaches presentation")
	_assert_rejected(state, ActionCommand.new(&"enemy_1", &"wait", [], state.turn_number), rng, "Action after defeat")


func _test_replays() -> void:
	var stable: bool = true
	var wins: bool = true
	var losses: bool = true
	var varied: bool = false
	var first: Dictionary = _simulate(0, false)
	for seed_value: int in range(64):
		var attack_run: Dictionary = _simulate(seed_value, false)
		var replay: Dictionary = _simulate(seed_value, false)
		var wait_run: Dictionary = _simulate(seed_value, true)
		stable = stable and attack_run == replay and wait_run == _simulate(seed_value, true)
		wins = wins and attack_run.final.outcome == &"victory"
		losses = losses and wait_run.final.outcome == &"defeat"
		varied = varied or attack_run.events != first.events
	_check(stable, "64 seeds: identical commands reproduce every event, state value, and RNG state")
	_check(varied, "Different seeds produce different damage sequences")
	_check(wins, "64 seeds: attacking can complete a battle in victory")
	_check(losses, "64 seeds: waiting can complete a battle in defeat")


func _simulate(seed_value: int, crew_waits: bool) -> Dictionary:
	var state: CombatState = _new_battle()
	var rng: RandomNumberGenerator = _rng(seed_value)
	var transcript: Array[Dictionary] = []
	for action_index: int in range(100):
		if state.outcome != &"ongoing":
			break
		var action: StringName = &"wait" if crew_waits and state.active_actor_id == &"crew_1" else &"attack"
		for event: CombatEvent in CombatRules.resolve_action(state, _command(state, action), rng):
			transcript.append({"kind": event.kind, "source": event.source_id, "target": event.target_id,
				"amount": event.amount, "health": event.health_after, "round": event.round_number, "outcome": event.outcome})
	return {"final": _snapshot(state, rng), "events": transcript}


func _new_battle() -> CombatState:
	return CombatRules.create_battle(ContentCatalogue.TEST_CREW, ContentCatalogue.TEST_ENEMY)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _command(state: CombatState, action: StringName) -> ActionCommand:
	var targets: Array[StringName] = []
	if action == &"attack":
		targets.append(state.get_opponent(state.get_actor(state.active_actor_id)).id)
	return ActionCommand.new(state.active_actor_id, action, targets, state.turn_number)


func _assert_rejected(state: CombatState, command: ActionCommand, rng: RandomNumberGenerator, label: String) -> void:
	var before: Dictionary = _snapshot(state, rng)
	var reason: String = CombatRules.validate_action(state, command)
	var events: Array[CombatEvent] = CombatRules.resolve_action(state, command, rng)
	_check(not reason.is_empty() and events.is_empty() and _snapshot(state, rng) == before, "%s: rejected without state, content, or RNG mutation" % label)


func _snapshot(state: CombatState, rng: RandomNumberGenerator) -> Dictionary:
	var actors: Array[Dictionary] = []
	for actor: ActorState in state.actors:
		actors.append({"id": actor.id, "side": actor.side, "health": actor.health, "definition": _definition_snapshot(actor.definition)})
	return {"actors": actors, "active": state.active_actor_id, "round": state.round_number,
		"turn": state.turn_number, "outcome": state.outcome, "rng": rng.state}


func _definition_snapshot(definition: ActorDefinition) -> Dictionary:
	return {"id": definition.id, "name": definition.display_name, "max_health": definition.max_health,
		"min": definition.damage_min, "max": definition.damage_max}


func _kinds(events: Array[CombatEvent]) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for event: CombatEvent in events:
		kinds.append(event.kind)
	return kinds


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		printerr("FAIL: ", description)
