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
	_test_class_content_and_support()
	_test_statuses_and_damage()
	_test_forced_movement()
	_test_enemy_policy_and_class_replays()
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


func _test_class_content_and_support() -> void:
	var ids: Array[StringName] = []
	for definition: ActorDefinition in ContentCatalogue.crew_party():
		_check(definition.is_valid() and definition.abilities.size() == 3, "%s has three valid authored skills" % definition.display_name)
		for ability: AbilityDefinition in definition.abilities:
			ids.append(ability.id)
	_check(ids.size() == 12 and _unique(ids), "Twelve distinct class abilities")
	for definition: ActorDefinition in [ContentCatalogue.MAULER, ContentCatalogue.NEEDLE, ContentCatalogue.CHORISTER, ContentCatalogue.BULWARK, ContentCatalogue.TUGGER]:
		_check(definition.is_valid(), "Valid enemy archetype: %s" % definition.display_name)
	var rng: RandomNumberGenerator = _rng(1729)
	var state: CombatState = _class_battle(rng)
	_activate(state, &"crew_4")
	_assert_rejected(state, _command(state, &"field_patch", &"enemy_1"), rng, "Healing rejects opponents")
	_assert_rejected(state, _command(state, &"field_patch", &"crew_1"), rng, "Healing rejects full health without spending uses")
	var target: ActorState = state.get_actor(&"crew_1")
	target.health = 30
	var before_rng: int = rng.state
	var events: Array[CombatEvent] = _take(state, &"crew_4", &"field_patch", target.id, rng)
	_check(target.health == 34 and events[0].kind == &"healed" and events[0].amount == 4, "Field patch caps healing at maximum health")
	_check(state.get_actor(&"crew_4").uses[&"field_patch"] == 1 and rng.state == before_rng, "Healing spends one use without rolling damage")
	target.health = 20
	_take(state, &"crew_4", &"field_patch", target.id, rng)
	_check(target.health == 28, "Field patch restores the authored eight HP")
	_activate(state, &"crew_4")
	_assert_rejected(state, _command(state, &"field_patch", target.id), rng, "Third heal is rejected without mutation")
	_check(CombatRules.ability_reason(state, &"crew_4", &"field_patch").contains("No uses left"), "Exhausted healing has a readable reason")
	var fresh: CombatState = _class_battle(_rng(1729))
	_check(fresh.get_actor(&"crew_4").uses.is_empty() and fresh.get_actor(&"crew_4").strain == 0, "New battle resets uses and battle-local strain")
	target.strain = 12
	events = _take(state, &"crew_4", &"stabilize", target.id, rng)
	_check(target.strain == 0 and events[0].amount == -12, "Strain reduction clamps at zero")
	_activate(state, &"crew_4")
	_assert_rejected(state, _command(state, &"stabilize", target.id), rng, "Strain reduction rejects zero strain")
	state = _class_battle(rng, true)
	target = state.get_actor(&"crew_1")
	target.strain = 95
	events = _take(state, &"enemy_3", &"signal_burst", target.id, rng)
	_check(target.strain == 100 and events[1].kind == &"strain_changed" and events[1].amount == 5, "Signal burst damages then adds strain capped at balance maximum")
	_check(state.get_actor(&"crew_2").strain == 0, "Strain is not shared between actor instances")
	var bad: AbilityDefinition = ContentCatalogue.MEDIC.abilities[1].duplicate(true) as AbilityDefinition
	bad.effects = [bad.effects[0].duplicate() as EffectDefinition]
	bad.effects[0].amount = 0
	_check(not bad.is_valid(), "Invalid healing effect rejected by content validation")
	bad = ContentCatalogue.TECHNICIAN.abilities[1].duplicate(true) as AbilityDefinition
	bad.effects = [bad.effects[0].duplicate() as EffectDefinition]
	bad.effects[0].status = bad.effects[0].status.duplicate() as StatusDefinition
	bad.effects[0].status.duration = 0
	_check(not bad.is_valid(), "Zero-duration status rejected by content validation")
	state = CombatRules.create_battle([ContentCatalogue.MEDIC, ContentCatalogue.MEDIC, ContentCatalogue.MEDIC, ContentCatalogue.MEDIC], [ContentCatalogue.TEST_ENEMY], rng)
	state.get_actor(&"crew_1").health = 16
	_take(state, &"crew_3", &"field_patch", &"crew_1", rng)
	_check(state.get_actor(&"crew_3").uses[&"field_patch"] == 1 and state.get_actor(&"crew_4").uses.is_empty()
		and ContentCatalogue.MEDIC.abilities[1].max_uses == 2, "Two Medics sharing one definition do not share healing uses")


func _test_statuses_and_damage() -> void:
	var rng: RandomNumberGenerator = _rng(500)
	var state: CombatState = _class_battle(rng)
	var target: ActorState = state.get_actor(&"crew_3")
	_take(state, &"crew_1", &"brace", target.id, rng)
	_check(target.get_status(StatusDefinition.Kind.PROTECTION) != null and state.get_actor(&"crew_2").statuses.is_empty(), "Brace protects only the chosen ally")
	var protection: StatusState = target.get_status(StatusDefinition.Kind.PROTECTION)
	_take(state, &"crew_1", &"brace", target.id, rng)
	_check(target.statuses.size() == 1 and target.statuses[0] != protection and target.statuses[0].remaining == 2, "Reapplying protection replaces and refreshes; no stacks")
	var ability: AbilityDefinition = ContentCatalogue.TEST_ENEMY.abilities[0]
	_check(CombatRules.adjusted_damage(target, ability, 7) == 3, "Protection halves direct damage and rounds down")
	var expected: RandomNumberGenerator = _rng(0)
	expected.state = rng.state
	var rolled: int = expected.randi_range(3, 4)
	var health_before: int = target.health
	var events: Array[CombatEvent] = _take(state, &"enemy_1", &"scramble", target.id, rng)
	_check(health_before - target.health == floori(rolled * 0.5) and events[0].amount == health_before - target.health, "Actual protected damage matches the displayed rule")
	var protected_definition: StatusDefinition = target.statuses[0].definition
	for turn_start: int in range(2):
		_seek_turn(state, target.id, rng)
		_check(target.get_status(StatusDefinition.Kind.PROTECTION) != null if turn_start == 0 else target.get_status(StatusDefinition.Kind.PROTECTION) == null,
			"Protection expires before selection at recipient turn start %d" % (turn_start + 1))
		CombatRules.resolve_action(state, _command(state, &"wait"), rng)
	_check(protected_definition.duration == 2 and protected_definition.magnitude == 50, "Runtime status expiry never edits its Resource")
	state = _class_battle(rng)
	target = state.get_actor(&"enemy_4")
	_take(state, &"crew_2", &"expose", target.id, rng)
	ability = ContentCatalogue.RANGER.get_ability(&"exploit")
	_check(CombatRules.adjusted_damage(target, ability, 5) == 7 and CombatRules.adjusted_damage(target, ability, 7) == 10, "Exposed raises Exploit signal's displayed range to 7–10")
	_check(CombatRules.adjusted_damage(target, ContentCatalogue.RANGER.abilities[0], 6) == 6, "Exposed is a marker; ordinary attacks get no extra bonus")
	expected.state = rng.state
	rolled = expected.randi_range(5, 7)
	health_before = target.health
	_take(state, &"crew_3", &"exploit", target.id, rng)
	_check(health_before - target.health == floori(rolled * 1.5) and target.get_status(StatusDefinition.Kind.EXPOSE) != null, "Exploit applies the conditional bonus without consuming Exposed")
	_take(state, &"enemy_2", &"enemy_guard", target.id, rng)
	_check(CombatRules.adjusted_damage(target, ability, 7) == 5, "Expose bonus and protection multiply before one final floor")
	for turn_start: int in range(2):
		_seek_turn(state, target.id, rng)
		CombatRules.resolve_action(state, _command(state, &"wait"), rng)
	_check(target.get_status(StatusDefinition.Kind.EXPOSE) == null, "Exposed expires after two recipient turn starts")

	state = _class_battle(rng)
	target = state.get_actor(&"enemy_1")
	_take(state, &"crew_2", &"cutting_beam", target.id, rng)
	var scorch: StatusState = target.get_status(StatusDefinition.Kind.DAMAGE_OVER_TIME)
	_check(scorch != null and scorch.remaining == 2, "Cutting beam applies the single DOT status after damage")
	_take(state, &"enemy_2", &"enemy_guard", target.id, rng)
	health_before = target.health
	_seek_turn(state, target.id, rng)
	_check(target.health == health_before - 2 and target.get_status(StatusDefinition.Kind.DAMAGE_OVER_TIME).remaining == 1, "Scorch ticks before target selection and bypasses protection")
	CombatRules.resolve_action(state, _command(state, &"wait"), rng)
	_seek_turn(state, target.id, rng)
	_check(target.health == health_before - 4 and target.get_status(StatusDefinition.Kind.DAMAGE_OVER_TIME) == null, "Scorch ticks exactly twice then expires")
	CombatRules.resolve_action(state, _command(state, &"wait"), rng)
	_seek_turn(state, target.id, rng)
	_check(target.health == health_before - 4, "Expired Scorch cannot tick again")
	_check(scorch.definition.duration == 2 and scorch.definition.magnitude == 2, "DOT countdown and damage leave authored status unchanged")

	# A lethal turn-start tick must never offer input to the dying actor.
	state = _class_battle(rng)
	_take(state, &"crew_2", &"cutting_beam", &"enemy_1", rng)
	state.get_actor(&"enemy_1").health = 1
	events = _seek_turn(state, &"enemy_1", rng)
	_check(state.get_actor(&"enemy_1") == null and state.active_actor_id != &"enemy_1", "Lethal DOT removes and skips the actor before input")
	_check(_event_index(events, &"dot_damage") >= 0 and _event_index(events, &"defeated") > _event_index(events, &"dot_damage"), "Lethal DOT emits damage then removal")
	_check(state.enemy_ranks[0] == &"enemy_2", "DOT removal compacts ranks")
	state = _class_battle(rng)
	_take(state, &"crew_2", &"cutting_beam", &"enemy_2", rng)
	_take(state, &"crew_2", &"cutting_beam", &"enemy_2", rng)
	target = state.get_actor(&"enemy_2")
	_check(target.statuses.size() == 1 and target.statuses[0].remaining == 2, "Repeated Scorch refreshes two ticks without stacking damage")
	state.get_actor(&"crew_2").health = 1
	_take(state, &"enemy_1", &"maul", &"crew_2", rng)
	target.health = 1
	events = _seek_turn(state, target.id, rng)
	var dot_index: int = _event_index(events, &"dot_damage")
	var death_index: int = _event_index(events, &"defeated")
	_check(state.get_actor(&"crew_2") == null and dot_index >= 0 and death_index > dot_index
		and events[dot_index].source_id == &"crew_2" and events[death_index].source_id == &"crew_2",
		"Scorch persists after its source dies and retains correct damage/death attribution")
	# Last-enemy DOT victory, and last-crew DOT defeat.
	for victim_team: ActorState.Team in [ActorState.Team.CREW, ActorState.Team.ENEMY]:
		state = _battle(rng, 1, 1)
		var victim: ActorState = state.get_actor(&"crew_1" if victim_team == ActorState.Team.CREW else &"enemy_1")
		var source: ActorState = state.get_actor(&"enemy_1" if victim_team == ActorState.Team.CREW else &"crew_1")
		victim.health = 1
		victim.statuses.append(StatusState.new(ContentCatalogue.TECHNICIAN.abilities[0].effects[0].status, source))
		_activate(state, source.id)
		events = CombatRules.resolve_action(state, _command(state, &"wait"), rng)
		_check(state.outcome == (&"defeat" if victim_team == ActorState.Team.CREW else &"victory")
			and events[-1].kind == &"battle_ended" and state.active_actor_id.is_empty(), "Last-actor DOT reaches the correct terminal outcome")


func _test_forced_movement() -> void:
	var rng: RandomNumberGenerator = _rng(12)
	var state: CombatState = _class_battle(rng)
	var events: Array[CombatEvent] = _take(state, &"crew_1", &"ram", &"enemy_1", rng)
	_check(state.enemy_ranks == [&"enemy_2", &"enemy_1", &"enemy_3", &"enemy_4"], "Ram damages then pushes the enemy one rank backward")
	_check(events[0].kind == &"damage" and events[1].kind == &"displaced", "Damage resolves before forced movement")
	_take(state, &"crew_2", &"tractor", &"enemy_4", rng)
	_check(state.enemy_ranks == [&"enemy_2", &"enemy_1", &"enemy_4", &"enemy_3"], "Tractor pulls one rank and shifts the intervening actor")
	_activate(state, &"crew_2")
	_assert_rejected(state, _command(state, &"tractor", &"enemy_2"), rng, "Tractor cannot pull rank 1")
	state = _class_battle(rng)
	_activate(state, &"crew_3")
	var order: Array[StringName] = state.round_order.duplicate()
	events = CombatRules.resolve_action(state, _command(state, &"fallback", &"enemy_1"), rng)
	_check(state.crew_ranks == [&"crew_1", &"crew_2", &"crew_4", &"crew_3"] and state.round_order == order and state.turn_number == 1,
		"Fallback shot moves its actor backward without extra or stolen turns")
	_check(CombatRules.ability_reason(state, &"crew_4", &"field_patch").is_empty() == false, "Movement respects healing target eligibility (all crew still full)")
	state = _class_battle(rng)
	state.get_actor(&"enemy_1").health = 1
	events = _take(state, &"crew_1", &"ram", &"enemy_1", rng)
	_check(state.get_actor(&"enemy_1") == null and _event_index(events, &"displaced") == -1, "Lethal damage skips forced movement on the removed target")
	state = CombatRules.create_battle([ContentCatalogue.RANGER], [ContentCatalogue.TEST_ENEMY], rng)
	_activate(state, &"crew_1")
	events = CombatRules.resolve_action(state, _command(state, &"fallback", &"enemy_1"), rng)
	_check(state.get_rank(&"crew_1") == 1 and events[0].kind == &"damage", "Fallback shot still damages when no backward space exists")
	state = _class_battle(rng)
	var before: Array[StringName] = state.crew_ranks.duplicate()
	_take(state, &"enemy_3", &"tow_hook", &"crew_4", rng)
	_check(state.crew_ranks == [before[0], before[1], before[3], before[2]], "Displacement specialist pulls a legal rear target")


func _test_enemy_policy_and_class_replays() -> void:
	var rng: RandomNumberGenerator = _rng(1729)
	var state: CombatState = _class_battle(rng)
	for actor_id: StringName in [&"enemy_1", &"enemy_2", &"enemy_3", &"enemy_4"]:
		_activate(state, actor_id)
		var before: Dictionary = _snapshot(state, rng)
		var choice: ActionCommand = EnemyPolicy.choose_action(state)
		_check(choice != null and CombatRules.validate_action(state, choice).is_empty() and _snapshot(state, rng) == before,
			"Enemy choice is legal and read-only: %s" % actor_id)
		var expected: StringName = {&"enemy_1": &"maul", &"enemy_2": &"enemy_guard", &"enemy_3": &"tow_hook", &"enemy_4": &"needle_volley"}[actor_id]
		_check(choice.action_id == expected, "Enemy uses its tactical specialty: %s" % actor_id)
	state = _class_battle(rng, true)
	_activate(state, &"enemy_3")
	_check(EnemyPolicy.choose_action(state).action_id == &"signal_burst", "Strain archetype chooses Signal burst")
	state = CombatRules.create_battle([ContentCatalogue.TEST_CREW], [ContentCatalogue.NEEDLE], rng)
	_activate(state, &"enemy_1")
	_check(EnemyPolicy.choose_action(state).action_id == &"scramble", "Displaced rear attacker uses its legal fallback from rank 1")
	var legal: bool = true
	var deterministic: bool = true
	var terminal: bool = true
	for patrol: bool in [false, true]:
		for seed_value: int in range(32):
			var first: Dictionary = _simulate_classes(seed_value, patrol)
			var second: Dictionary = _simulate_classes(seed_value, patrol)
			legal = legal and first.legal
			deterministic = deterministic and first == second
			terminal = terminal and first.final.outcome != &"ongoing"
	_check(legal, "64 class battles: AI never chooses an illegal action through movement, statuses and removal")
	_check(deterministic, "64 class battles: same seed and choices reproduce all runtime state and effect events")
	_check(terminal, "64 class battles reach a terminal outcome without a softlock")
	for patrol: bool in [false, true]:
		var result: Dictionary = _simulate_classes(1729, patrol)
		print("M4 DEFAULT PATROL ", patrol, ": ", result.final.outcome, " / round ", result.final.round, " / turn ", result.final.turn)


func _simulate_classes(seed_value: int, patrol: bool) -> Dictionary:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var state: CombatState = _class_battle(rng, patrol)
	var events: Array[Dictionary] = []
	var legal: bool = true
	for index: int in range(500):
		if state.outcome != &"ongoing":
			break
		var command: ActionCommand = EnemyPolicy.choose_action(state)
		legal = legal and command != null and CombatRules.validate_action(state, command).is_empty()
		if not legal:
			break
		for event: CombatEvent in CombatRules.resolve_action(state, command, rng):
			events.append({"kind": event.kind, "source": event.source_id, "target": event.target_id, "amount": event.amount,
				"hp": event.health_after, "strain": event.strain_after, "status": event.status_name,
				"duration": event.duration, "ability": event.ability_name, "ranks": event.rank_ids.duplicate()})
	return {"legal": legal, "final": _snapshot(state, rng), "events": events}


func _class_battle(rng: RandomNumberGenerator, patrol: bool = false) -> CombatState:
	return CombatRules.create_battle(ContentCatalogue.crew_party(), ContentCatalogue.enemy_party(patrol), rng)


func _take(state: CombatState, actor_id: StringName, ability: StringName, target: StringName, rng: RandomNumberGenerator) -> Array[CombatEvent]:
	_activate(state, actor_id)
	# Keep the target later in this valid fixture queue to inspect the applied effect.
	if target != actor_id:
		state.round_order.erase(target)
		state.round_order.append(target)
	return CombatRules.resolve_action(state, _command(state, ability, target), rng)


func _seek_turn(state: CombatState, actor_id: StringName, rng: RandomNumberGenerator) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	for index: int in range(32):
		if state.active_actor_id == actor_id or state.get_actor(actor_id) == null or state.outcome != &"ongoing":
			return events
		events.append_array(CombatRules.resolve_action(state, _command(state, &"wait"), rng))
	_check(false, "Requested actor turn was not reached")
	return events


func _event_index(events: Array[CombatEvent], kind: StringName) -> int:
	for index: int in range(events.size()):
		if events[index].kind == kind:
			return index
	return -1


func _unique(ids: Array[StringName]) -> bool:
	var seen: Array[StringName] = []
	for id: StringName in ids:
		if id in seen:
			return false
		seen.append(id)
	return true



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
		var statuses: Array[Dictionary] = []
		for status: StatusState in actor.statuses:
			statuses.append({"id": status.definition.id, "kind": status.definition.kind, "duration": status.definition.duration,
				"magnitude": status.definition.magnitude, "remaining": status.remaining, "source": status.source_id, "source_name": status.source_name})
		actors.append({"id": actor.id, "side": actor.side, "health": actor.health, "strain": actor.strain,
			"uses": actor.uses.duplicate(), "statuses": statuses, "definition": _definition_snapshot(actor.definition)})
	return {"actors": actors, "active": state.active_actor_id, "round": state.round_number,
		"turn": state.turn_number, "outcome": state.outcome, "rng": rng.state,
		"crew": state.crew_ranks.duplicate(), "enemy": state.enemy_ranks.duplicate(),
		"order": state.round_order.duplicate(), "cursor": state.turn_cursor,
		"rolls": state.initiative_rolls.duplicate(), "scores": state.initiative_scores.duplicate()}


func _definition_snapshot(definition: ActorDefinition) -> Dictionary:
	var abilities: Array[Dictionary] = []
	for ability: AbilityDefinition in definition.abilities:
		var effects: Array[Dictionary] = []
		for effect: EffectDefinition in ability.effects:
			effects.append({"kind": effect.kind, "amount": effect.amount, "self": effect.on_actor,
				"status": [] if effect.status == null else [effect.status.id, effect.status.kind, effect.status.duration, effect.status.magnitude]})
		abilities.append({"id": ability.id, "name": ability.display_name, "actor_ranks": ability.actor_ranks.duplicate(),
			"target_ranks": ability.target_ranks.duplicate(), "min": ability.damage_min, "max": ability.damage_max,
			"team": ability.target_team, "self": ability.allow_self, "max_uses": ability.max_uses,
			"exposed_multiplier": ability.exposed_multiplier, "effects": effects})
	return {"id": definition.id, "name": definition.display_name, "max_health": definition.max_health,
		"speed": definition.speed, "abilities": abilities}


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		printerr("FAIL: ", description)
