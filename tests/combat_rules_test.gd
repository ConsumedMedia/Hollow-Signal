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
	_test_vulnerability()
	_test_shaken_and_power()
	_test_expedition_carryover()
	_test_exploration_rules()
	_test_inventory_and_room_events()
	_test_full_expedition()
	_test_campaign_loop()
	_test_save_round_trip()
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
		actors.append({"id": actor.id, "side": actor.side, "health": actor.health, "strain": actor.strain, "shaken": actor.shaken, "dead": actor.dead,
			"uses": actor.uses.duplicate(), "statuses": statuses, "definition": _definition_snapshot(actor.definition)})
	var crew: Array[Dictionary] = []
	for member: CrewState in state.expedition.crew:
		crew.append({"id": member.id, "health": member.health, "strain": member.strain, "shaken": member.shaken, "dead": member.dead})
	return {"actors": actors, "active": state.active_actor_id, "round": state.round_number,
		"persistent": crew, "power": state.expedition.power, "failed": state.expedition.failed, "battle_active": state.expedition.battle_active,
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


func _test_vulnerability() -> void:
	var rng: RandomNumberGenerator = _rng(1729)
	var state: CombatState = _class_battle(rng)
	var target: ActorState = state.get_actor(&"crew_1")
	target.health = 1
	var events: Array[CombatEvent] = _take(state, &"enemy_1", &"maul", target.id, rng)
	_check(target.is_downed() and state.get_rank(target.id) == 1 and state.crew_ranks.size() == 4, "Zero HP downs crew without removing their rank")
	_check(_event_index(events, &"downed") >= 0 and not target.dead, "Downing emits a distinct event, not death")
	_activate(state, target.id)
	_assert_rejected(state, _command(state, &"wait"), rng, "Downed actor cannot act")
	_check(CombatRules.get_legal_actions(state, target.id).is_empty(), "Downed actor has no legal actions")
	events = _take(state, &"crew_4", &"field_patch", target.id, rng)
	_check(target.health == 8 and target.is_conscious() and _event_index(events, &"revived") >= 0, "Field patch revives at zero health")
	_check(state.expedition.get_crew(target.id).health == 8, "Revival synchronizes the persistent individual")
	target.health = 1
	_take(state, &"enemy_1", &"maul", target.id, rng)
	events = _take(state, &"enemy_1", &"maul", target.id, rng)
	_check(target.dead and state.get_actor(target.id) == null and state.crew_ranks[0] == &"crew_2", "Further damage permanently kills and compacts crew ranks")
	_check(state.expedition.get_crew(target.id).dead and _event_index(events, &"died") >= 0, "Death remains recorded after removing the combat actor")
	_activate(state, &"crew_4")
	_assert_rejected(state, _command(state, &"field_patch", target.id), rng, "Healing cannot resurrect dead crew")
	state = _class_battle(rng)
	target = state.get_actor(&"crew_1")
	target.health = 0
	var zero_events: Array[CombatEvent] = []
	CombatRules._damage(state, state.get_actor(&"enemy_1"), target, 0, zero_events)
	_check(target.is_downed() and not target.dead, "Damage rounded to zero does not kill a downed crew member")

	# A downed ally can be swapped; this must not add an initiative slot.
	state = _class_battle(rng)
	state.get_actor(&"crew_2").health = 0
	var order: Array[StringName] = state.round_order.duplicate()
	_activate(state, &"crew_1")
	order = state.round_order.duplicate()
	events = CombatRules.resolve_action(state, _command(state, &"move", &"crew_2"), rng)
	_check(state.get_rank(&"crew_2") == 1 and state.round_order == order and state.turn_number >= 1 and events[0].kind == &"moved", "Moving a downed ally preserves the round queue and spends one action (skipped slots also advance the stale-input token)")

	# Revived before its existing slot: acts once. Revived after its slot: next round.
	for already_passed: bool in [false, true]:
		state = _class_battle(rng)
		target = state.get_actor(&"crew_1")
		target.health = 0
		state.round_order.assign([&"crew_1", &"crew_4", &"crew_2", &"crew_3", &"enemy_1", &"enemy_2", &"enemy_3", &"enemy_4"] if already_passed else [&"crew_4", &"crew_1", &"crew_2", &"crew_3", &"enemy_1", &"enemy_2", &"enemy_3", &"enemy_4"])
		state.turn_cursor = 1 if already_passed else 0
		state.active_actor_id = &"crew_4"
		CombatRules.resolve_action(state, _command(state, &"field_patch", target.id), rng)
		var actions: int = 0
		while state.round_number == 1:
			if state.active_actor_id == target.id:
				actions += 1
			CombatRules.resolve_action(state, _command(state, &"wait"), rng)
		_check(actions == (0 if already_passed else 1), "Revival respects already-used initiative slot: %s" % already_passed)

	# DOT continues on a downed actor, including slots in subsequent rounds.
	state = _class_battle(rng)
	target = state.get_actor(&"crew_1")
	target.health = 1
	target.statuses.append(StatusState.new(ContentCatalogue.TECHNICIAN.abilities[0].effects[0].status, state.get_actor(&"enemy_1")))
	var downed_seen: bool = false
	var died_seen: bool = false
	for index: int in range(24):
		if state.outcome != &"ongoing" or target.dead:
			break
		events = CombatRules.resolve_action(state, _command(state, &"wait"), rng)
		downed_seen = downed_seen or _event_index(events, &"downed") >= 0
		died_seen = died_seen or _event_index(events, &"died") >= 0
		_check(state.active_actor_id != target.id or target.is_conscious(), "DOT-downed actor is never offered input")
	_check(downed_seen and died_seen and target.dead, "Two Scorch ticks down then kill crew across rounds")

	state = _battle(rng, 2, 1)
	state.get_actor(&"crew_2").health = 0
	state.get_actor(&"enemy_1").health = 1
	_take(state, &"crew_1", &"strike", &"enemy_1", rng)
	_check(state.outcome == &"victory" and state.get_actor(&"crew_2").health == 1 and state.expedition.get_crew(&"crew_2").health == 1, "Downed victory survivors recover to one HP exactly once")
	state = _battle(rng, 2, 1)
	state.get_actor(&"crew_1").health = 0
	state.get_actor(&"crew_2").health = 1
	events = _take(state, &"enemy_1", &"strike", &"crew_2", rng)
	_check(state.outcome == &"defeat" and state.expedition.failed and state.crew_ranks.is_empty(), "No conscious crew ends the expedition immediately")
	_check(state.expedition.crew[0].dead and state.expedition.crew[1].dead, "Defeat loses every deployed crew member, including downed crew")
	_assert_rejected(state, _command(state, &"wait"), rng, "Terminal defeat cannot continue")
	var saved_rng: int = rng.state
	_check(CombatRules.create_battle([], ContentCatalogue.enemy_party(), rng, state.expedition) == null and rng.state == saved_rng, "Failed expedition cannot restart its dead crew")

	# Both sides eliminated in one action resolves as defeat, not victory.
	state = _battle(rng, 1, 1)
	var ability: AbilityDefinition = state.get_actor(&"crew_1").definition.abilities[0]
	state.get_actor(&"crew_1").health = 0
	state.get_actor(&"enemy_1").health = 0
	var terminal_events: Array[CombatEvent] = []
	CombatRules._finish_outcome(state, terminal_events)
	_check(state.outcome == &"defeat" and state.expedition.get_crew(&"crew_1").dead and ability.damage_max > 0, "Simultaneous elimination resolves as defeat")


func _test_shaken_and_power() -> void:
	var rng: RandomNumberGenerator = _rng(71)
	var state: CombatState = _class_battle(rng, true)
	var target: ActorState = state.get_actor(&"crew_3")
	target.strain = 99
	var events: Array[CombatEvent] = _take(state, &"enemy_3", &"signal_burst", target.id, rng)
	_check(target.strain == 100 and target.shaken and _event_index(events, &"shaken") >= 0, "At 100 strain Shaken applies and emits an event")
	for strain_value: int in [100, 99, 50, 49, 0]:
		_check(CombatRules.shaken_after(strain_value, true) == (strain_value >= 50), "Shaken hysteresis at strain %d" % strain_value)
	_check(not CombatRules.shaken_after(99, false), "Unshaken crew do not acquire Shaken below 100")
	target.strain = 70
	_take(state, &"crew_4", &"stabilize", target.id, rng)
	_check(target.strain == 50 and target.shaken, "Medic reaching exactly 50 does not clear Shaken")
	events = _take(state, &"crew_4", &"stabilize", target.id, rng)
	_check(target.strain == 30 and not target.shaken and _event_index(events, &"shaken_cleared") >= 0, "Medic reducing below 50 clears Shaken")
	_check(state.expedition.get_crew(target.id).strain == 30 and not state.expedition.get_crew(target.id).shaken, "Strain and Shaken persist together, including clearing")

	state = _class_battle(rng)
	var source: ActorState = state.get_actor(&"crew_3")
	target = state.get_actor(&"enemy_1")
	var ability: AbilityDefinition = source.definition.abilities[1]
	source.shaken = true
	target.statuses.append(StatusState.new(ContentCatalogue.TECHNICIAN.abilities[1].effects[0].status, source))
	target.statuses.append(StatusState.new(ContentCatalogue.BREACHER.abilities[1].effects[0].status, target))
	_check(CombatRules.adjusted_damage(target, ability, 7, source, true) == 5, "Shaken, Overcharge, Exposed and protection multiply before one floor")
	_check(CombatRules.adjusted_damage(target, source.definition.abilities[0], 6, source) == 2, "Shaken applies to ordinary damaging abilities")
	_activate(state, source.id)
	for action: StringName in [&"wait", &"move"]:
		var invalid: ActionCommand = _command(state, action, &"crew_2" if action == &"move" else &"")
		invalid.overcharge = true
		_assert_rejected(state, invalid, rng, "Overcharge rejects " + String(action))
	_activate(state, &"crew_4")
	var support: ActionCommand = _command(state, &"field_patch", &"crew_1")
	support.overcharge = true
	_assert_rejected(state, support, rng, "Overcharge rejects healing")
	_activate(state, &"enemy_1")
	var enemy: ActionCommand = _command(state, &"maul", &"crew_1")
	enemy.overcharge = true
	_assert_rejected(state, enemy, rng, "Enemies cannot spend shared crew power")
	_activate(state, source.id)
	state.expedition.power = 9
	var charged: ActionCommand = _command(state, &"exploit", target.id)
	charged.overcharge = true
	_assert_rejected(state, charged, rng, "Insufficient power")
	state.expedition.power = 10
	var hp: int = target.health
	var expected_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	expected_rng.state = rng.state
	var expected: int = CombatRules.adjusted_damage(target, ability, expected_rng.randi_range(ability.damage_min, ability.damage_max), source, true)
	events = CombatRules.resolve_action(state, charged, rng)
	_check(state.expedition.power == 0 and target.health == hp - expected, "Exactly 10 power buys the displayed Overcharge damage and can reach zero")
	_check(events[0].kind == &"power_spent" and events[0].power_after == 0 and events[1].kind == &"damage", "Power event precedes damage and holds a value snapshot")
	_assert_rejected(state, charged, rng, "Repeated Overcharge cannot spend power twice")
	_check(state.outcome == &"ongoing", "Zero power does not automatically end a battle")
	var snapshot: Dictionary = _snapshot(state, rng)
	_check(not CombatRules.traverse_test_corridor(state.expedition) and _snapshot(state, rng) == snapshot, "Traversal cannot spend power or add strain during combat")
	for boundary: int in [100, 50, 49, 25, 24, 0]:
		_check(CombatRules.room_strain(boundary) == (0 if boundary >= 50 else (2 if boundary >= 25 else 5)), "Room strain threshold at power %d" % boundary)
	for before_power: int in [55, 54, 30, 29, 5, 0]:
		var expedition: ExpeditionState = CombatRules.new_expedition(ContentCatalogue.crew_party())
		expedition.power = before_power
		expedition.crew[0].strain = 99
		_check(CombatRules.traverse_test_corridor(expedition) and expedition.power == maxi(0, before_power - 5), "Corridor spends five with zero clamp from %d" % before_power)
		_check(expedition.crew[1].strain == CombatRules.room_strain(expedition.power), "Room pressure uses power AFTER traversal")
		_check(expedition.crew[0].shaken == (expedition.power < 50), "Low-power entry can cross Shaken threshold")
	_check(CombatRules.BALANCE.is_valid() and CombatRules.new_expedition(ContentCatalogue.crew_party()).power == 100, "Valid balance starts expeditions at 100 power")
	var bad: CombatBalance = CombatRules.BALANCE.duplicate() as CombatBalance
	bad.overcharge_cost = 0
	_check(not bad.is_valid(), "Invalid Overcharge balance rejected")


func _test_expedition_carryover() -> void:
	var rng: RandomNumberGenerator = _rng(29)
	var state: CombatState = _class_battle(rng)
	var expedition: ExpeditionState = state.expedition
	# Keep C1 alive, lose C2, retain Shaken at 70 on C3, and recover downed C4.
	state.get_actor(&"crew_2").health = 0
	_take(state, &"enemy_1", &"maul", &"crew_2", rng)
	state.get_actor(&"crew_3").strain = 70
	state.get_actor(&"crew_3").shaken = true
	state.get_actor(&"crew_4").health = 0
	expedition.power = 30
	while state.outcome == &"ongoing":
		var victim: ActorState = state.actor_at(ActorState.Team.ENEMY, 1)
		victim.health = 1
		_take(state, &"crew_1", &"breach_strike", victim.id, rng)
	_check(state.outcome == &"victory" and not expedition.battle_active, "Victory releases the expedition for the next battle")
	var health: int = expedition.get_crew(&"crew_1").health
	CombatRules.traverse_test_corridor(expedition)
	var next: CombatState = CombatRules.create_battle(ContentCatalogue.crew_party(), ContentCatalogue.enemy_party(), rng, expedition)
	_check(next != null and next.expedition == expedition and next.crew_ranks == [&"crew_1", &"crew_3", &"crew_4"], "Next battle preserves IDs, formation and death without resurrecting the lost crew")
	_check(next.get_actor(&"crew_1").health == health and next.get_actor(&"crew_4").health == 1, "Survivor wounds and victory recovery carry into the next battle")
	_check(next.get_actor(&"crew_3").strain == 72 and next.get_actor(&"crew_3").shaken and expedition.power == 25, "Strain, Shaken hysteresis and spent power persist between battles")
	var clean_temporary: bool = true
	for actor: ActorState in next.actors:
		clean_temporary = clean_temporary and actor.uses.is_empty() and actor.statuses.is_empty()
	_check(clean_temporary, "New battle clears temporary effects and use limits, not persistent crew state")
	var before: Dictionary = _snapshot(next, rng)
	_check(CombatRules.create_battle([], ContentCatalogue.enemy_party(), rng, expedition) == null and _snapshot(next, rng) == before, "One expedition cannot be used by two active battles")
	var fresh: CombatState = _class_battle(_rng(29))
	_check(fresh.crew_ranks.size() == 4 and fresh.get_actor(&"crew_3").strain == 0 and fresh.expedition.power == 100, "Explicit fresh expedition is independent from the old dead crew records")
	_check(expedition.get_crew(&"crew_2").dead and expedition.get_crew(&"crew_3").shaken, "Creating a fresh test expedition never edits the prior expedition")


func _test_exploration_rules() -> void:
	var ship: ShipDefinition = ContentCatalogue.SHIP
	_check(ship.is_valid() and ship.rooms.size() == 8, "Authored eight-room graph validates connected bidirectional links and content")
	var reachable: Array[StringName] = [ship.entry_id]
	var cursor: int = 0
	while cursor < reachable.size():
		for neighbor: StringName in ship.get_room(reachable[cursor]).links:
			if neighbor not in [&"salvage", &"hazard"] and neighbor not in reachable:
				reachable.append(neighbor)
		cursor += 1
	_check(ship.boss_id in reachable and &"salvage" not in reachable, "Boss route is reachable without the optional salvage/hazard branch")
	var state: ExpeditionState = ExpeditionRules.create(ship, ContentCatalogue.crew_party())
	_check(state.current_room == ship.entry_id and state.rooms[ship.entry_id].resolved and state.inventory.capacity == 12, "New expedition starts in resolved airlock with twelve slots")
	_check(state.inventory.stacks.size() == 1 and state.inventory.stacks[0].quantity == 2, "Two starting power cells share one stack")
	var before_power: int = state.power
	_check(not ExpeditionRules.begin_travel(state, ship.boss_id) and state.power == before_power and state.destination.is_empty(), "Nonadjacent travel does not mutate state")
	state.power = 29
	_check(ExpeditionRules.begin_travel(state, &"receiving") and state.power == 24 and state.current_room == &"airlock", "Travel charges five once before the corridor presentation")
	_check(state.crew[0].strain == 0 and not ExpeditionRules.begin_travel(state, &"receiving"), "Repeated travel during a corridor is rejected and room strain waits for arrival")
	_check(not ExpeditionRules.use_power_cell(state, 0), "Power cells cannot be used while traversing")
	_check(ExpeditionRules.arrive(state) and state.current_room == &"receiving" and state.crew[0].strain == 5, "Arrival applies low-power strain and marks the destination visited")
	_check(not ExpeditionRules.arrive(state) and state.crew[0].strain == 5, "Duplicate arrival cannot add strain twice")
	_check(not ExpeditionRules.begin_travel(state, &"junction"), "Unresolved combat room cannot be bypassed")
	var room: RoomDefinition = ExpeditionRules.begin_encounter(state)
	_check(room != null and ExpeditionRules.begin_encounter(state) == null, "Encounter entry reserves the current room exactly once")
	var rng: RandomNumberGenerator = _rng(state.rooms[room.id].encounter_seed)
	var battle: CombatState = CombatRules.create_battle([], room.enemies, rng, state)
	_check(battle.expedition == state and battle.get_actor(&"crew_1").strain == 5 and state.power == 24, "Combat entry receives the same expedition, crew strain and power")
	_check(not ExpeditionRules.use_power_cell(state, 0) and not ExpeditionRules.finish_encounter(state, battle), "Power cells and battle return reject active combat")
	for action: int in range(400):
		if battle.outcome != &"ongoing":
			break
		var command: ActionCommand = EnemyPolicy.choose_action(battle)
		CombatRules.resolve_action(battle, command, rng)
	_check(ExpeditionRules.finish_encounter(state, battle) and state.rooms[room.id].resolved, "Combat victory resolves the room and returns survivor state")
	var cargo: int = _cargo_count(state)
	_check(not ExpeditionRules.finish_encounter(state, battle) and _cargo_count(state) == cargo, "Duplicate battle return does not duplicate rewards")
	_check(ExpeditionRules.begin_travel(state, &"airlock") and ExpeditionRules.arrive(state), "Backtracking through cleared rooms is allowed")
	var prior_power: int = state.power
	_check(ExpeditionRules.begin_travel(state, &"receiving") and ExpeditionRules.arrive(state), "Revisiting a cleared encounter is allowed")
	_check(state.power == maxi(0, prior_power - 5) and ExpeditionRules.begin_encounter(state) == null and _cargo_count(state) == cargo, "Backtracking consumes power without regenerating fights or loot")
	ExpeditionRules.begin_travel(state, &"junction")
	ExpeditionRules.arrive(state)
	ExpeditionRules.begin_encounter(state)
	_check(not ExpeditionRules.finish_encounter(state, battle) and not state.rooms[&"junction"].resolved, "A stale battle result cannot resolve a different room")


func _test_inventory_and_room_events() -> void:
	var state: ExpeditionState = ExpeditionRules.create(ContentCatalogue.SHIP, ContentCatalogue.crew_party())
	state.power = 90
	var cells: ItemDefinition = state.inventory.stacks[0].definition
	_check(ExpeditionRules.use_power_cell(state, 0) and state.power == 100 and state.inventory.stacks[0].quantity == 1, "Outside-combat cell restores 25 with cap 100 and consumes one")
	_check(not ExpeditionRules.use_power_cell(state, 0) and state.inventory.stacks[0].quantity == 1, "A cell cannot be wasted at full power")
	var other: InventoryState = InventoryState.new()
	other.add(cells, 2)
	state.power = 0
	ExpeditionRules.use_power_cell(state, 0)
	_check(other.stacks[0].quantity == 2 and state.inventory.stacks.is_empty() and cells.max_stack == 3, "Shared item Resources never share mutable stack quantities")

	state.current_room = &"salvage"
	state.rooms[&"salvage"].visited = true
	_check(ExpeditionRules.inspect(state, &"accept"), "Salvage collection resolves its authored event")
	_check(state.inventory.stacks.size() == 12 and not state.pending_loot.is_empty(), "Oversized cargo fills exactly twelve slots and retains explicit pending loot")
	var count: int = _cargo_count(state)
	_check(not ExpeditionRules.inspect(state, &"accept") and _cargo_count(state) == count, "Repeated salvage selection never duplicates loot")
	_check(not ExpeditionRules.begin_travel(state, &"hazard"), "Travel is blocked while overflow needs a keep/discard choice")
	var incoming: ItemStack = state.pending_loot[0]
	var pending_before: int = incoming.quantity
	_check(ExpeditionRules.discard_slot(state, 0) and (state.pending_loot.is_empty() or state.pending_loot[0].quantity < pending_before), "Discarding a stored stack allows incoming cargo into the freed slot")
	while not state.pending_loot.is_empty():
		_check(ExpeditionRules.discard_pending(state), "Explicitly leaving incoming cargo resolves the overflow")
	_check(state.inventory.stacks.size() <= 12 and state.rooms[&"salvage"].resolved, "Overflow decision cannot create extra slots or reopen the resolved event")
	count = _cargo_count(state)
	_check(not ExpeditionRules.discard_pending(state) and not ExpeditionRules.discard_slot(state, 99) and _cargo_count(state) == count, "Invalid discard leaves cargo unchanged")

	state.current_room = &"hazard"
	state.crew[0].strain = 95
	_check(ExpeditionRules.inspect(state, &"accept") and state.crew[0].strain == 100 and state.crew[0].shaken, "Hazard choice adds authored strain and can trigger Shaken")
	count = _cargo_count(state)
	_check(not ExpeditionRules.inspect(state, &"accept") and _cargo_count(state) == count, "Hazard cannot be harvested repeatedly")
	while not state.pending_loot.is_empty():
		ExpeditionRules.discard_pending(state)
	state.current_room = &"safe_room"
	state.crew[0].health = 1
	state.crew[0].strain = 70
	state.crew[0].shaken = true
	state.crew[1].dead = true
	state.crew[1].health = 0
	_check(ExpeditionRules.inspect(state, &"accept") and state.crew[0].health == 13 and state.crew[0].strain == 40 and not state.crew[0].shaken, "Safe room applies one authored rest and clears Shaken below 50")
	_check(state.crew[1].dead and state.crew[1].health == 0 and not ExpeditionRules.inspect(state, &"accept"), "Safe room never resurrects the dead or grants repeated recovery")
	state = ExpeditionRules.create(ContentCatalogue.SHIP, ContentCatalogue.crew_party())
	state.current_room = &"hazard"
	count = _cargo_count(state)
	_check(ExpeditionRules.inspect(state, &"leave") and state.crew[0].strain == 0 and _cargo_count(state) == count, "Sealing the hazard resolves it without strain or loot")
	_check(not ExpeditionRules.inspect(state, &"accept"), "A skipped event cannot be collected on a revisit")


func _test_full_expedition() -> void:
	var state: ExpeditionState = ExpeditionRules.create(ContentCatalogue.SHIP, ContentCatalogue.crew_party())
	for destination: StringName in [&"receiving", &"junction", &"safe_room", &"containment", &"signal_core"]:
		if state.failed:
			break
		if state.power <= 75:
			for index: int in range(state.inventory.stacks.size()):
				if state.inventory.stacks[index].definition.power_restored > 0:
					ExpeditionRules.use_power_cell(state, index)
					break
		_check(ExpeditionRules.begin_travel(state, destination) and ExpeditionRules.arrive(state), "Natural expedition reaches " + String(destination))
		var definition: RoomDefinition = state.ship.get_room(destination)
		if definition.kind == RoomDefinition.Kind.SAFE:
			ExpeditionRules.inspect(state, &"accept")
			continue
		var room: RoomDefinition = ExpeditionRules.begin_encounter(state)
		var rng: RandomNumberGenerator = _rng(state.rooms[destination].encounter_seed)
		var battle: CombatState = CombatRules.create_battle([], room.enemies, rng, state)
		for action: int in range(400):
			if battle.outcome != &"ongoing":
				break
			var command: ActionCommand = EnemyPolicy.choose_action(battle)
			if command.action_id == &"wait":
				for candidate: ActionCommand in CombatRules.get_legal_actions(battle, battle.active_actor_id):
					if candidate.action_id == &"move":
						command = candidate
						break
			CombatRules.resolve_action(battle, command, rng)
		_check(battle.outcome == &"victory", "Natural expedition wins " + String(destination))
		_check(ExpeditionRules.finish_encounter(state, battle), "Battle resolution returns to " + String(destination))
	_check(state.boss_cleared and not state.failed and state.current_room == &"signal_core", "Authored expedition reaches and clears the single-rank boss placeholder")
	_check(not state.rooms[&"salvage"].visited and not state.rooms[&"hazard"].visited, "Successful main route does not require the optional branch")


func _test_campaign_loop() -> void:
	var retreat_expedition: ExpeditionState = CombatRules.new_expedition(ContentCatalogue.crew_party())
	var retreat_rng: RandomNumberGenerator = _rng(18)
	var retreat_battle: CombatState = CombatRules.create_battle([], ContentCatalogue.enemy_party(), retreat_rng, retreat_expedition)
	while retreat_battle.get_actor(retreat_battle.active_actor_id).side == ActorState.Team.ENEMY:
		CombatRules.resolve_action(retreat_battle, EnemyPolicy.choose_action(retreat_battle), retreat_rng)
	var retreat_events: Array[CombatEvent] = CombatRules.retreat(retreat_battle)
	_check(retreat_events.size() == 1 and retreat_battle.outcome == &"retreat" and not retreat_expedition.battle_active, "Retreat is guaranteed on a conscious crew turn and ends combat")
	_check(CombatRules.retreat(retreat_battle).is_empty(), "Terminal retreat cannot resolve twice")
	var campaign: CampaignState = CampaignRules.create_campaign()
	_check(CampaignRules.BALANCE.is_valid(), "Authored campaign economy values validate")
	_check(campaign.roster.size() == 8 and campaign.party_ids.size() == 4, "Campaign starts with eight individuals and four selected ranks")
	var class_counts: Dictionary[StringName, int] = {}
	for member: CrewState in campaign.roster:
		class_counts[member.definition.id] = class_counts.get(member.definition.id, 0) + 1
	_check(class_counts.size() == 4 and class_counts.values().all(func(count: int) -> bool: return count == 2), "Starting roster has two of each class")
	_check(ContentCatalogue.MODULES.size() == 6 and ContentCatalogue.MODULES.all(func(module: ModuleDefinition) -> bool: return module.is_valid()), "Six valid authored modules are available")
	var first_id: StringName = campaign.party_ids[0]
	_check(CampaignRules.move_party(campaign, first_id, 1) and campaign.party_ids[1] == first_id, "Hub rank ordering swaps adjacent selected crew")
	_check(CampaignRules.toggle_party(campaign, first_id) and campaign.party_ids.size() == 3, "Selected crew can be removed from the party")
	_check(CampaignRules.deploy(campaign) == null, "Deployment requires exactly four living crew")
	_check(CampaignRules.toggle_party(campaign, first_id), "Crew can be restored to the selected party")
	var member: CrewState = campaign.get_crew(first_id)
	member.health = 1
	member.strain = 80
	member.shaken = true
	_check(CampaignRules.restore_health_free(campaign, first_id) and member.health == member.max_health(), "Hub health restoration is free and complete")
	var currency: int = campaign.salvage
	_check(CampaignRules.recover_strain(campaign, first_id) and member.strain == 50 and member.shaken and campaign.salvage == currency - 5, "Paid recovery reduces persistent strain and respects Shaken hysteresis")
	_check(CampaignRules.recover_strain(campaign, first_id) and member.strain == 20 and not member.shaken, "Further recovery clears Shaken below 50")
	campaign.salvage = 100
	var plating: ModuleDefinition = ContentCatalogue.MODULES[0]
	_check(CampaignRules.buy_module(campaign, plating.id) and not CampaignRules.buy_module(campaign, plating.id), "A collectible module can be purchased exactly once")
	var old_max: int = member.max_health()
	_check(CampaignRules.equip_module(campaign, first_id, plating.id) and member.max_health() == old_max + plating.health_bonus, "One equipped module changes runtime stats without mutating actor content")
	var other: CrewState = campaign.roster[4]
	member.health = member.max_health()
	_check(CampaignRules.equip_module(campaign, other.id, plating.id) and member.module_id.is_empty() and other.module_id == plating.id and member.health == member.max_health(), "A module has one crew owner, moves cleanly and clamps former-owner health")
	_check(CampaignRules.buy_upgrade(campaign) and campaign.upgrade_tier == 1 and campaign.roster.all(func(crew: CrewState) -> bool: return crew.upgrade_health_bonus == 2), "Single upgrade tier applies its authored campaign-wide health bonus")
	_check(not CampaignRules.buy_upgrade(campaign), "Upgrade reward cannot be purchased twice")
	var roster_before: int = campaign.roster.size()
	_check(CampaignRules.recruit_free(campaign, ContentCatalogue.MEDIC) != null and campaign.roster.size() == roster_before + 1, "Basic recruitment is free")
	var expedition: ExpeditionState = CampaignRules.deploy(campaign)
	_check(expedition != null and expedition.crew.size() == 4 and campaign.active_expedition == expedition, "Prepared party deploys with the same persistent crew records")
	_check(campaign.starting_cells == 0 and expedition.inventory.stacks[0].quantity == 2, "Purchased supplies transfer to one expedition instead of duplicating between deployments")
	_check(not CampaignRules.toggle_party(campaign, campaign.party_ids[0]) and CampaignRules.recruit_free(campaign, ContentCatalogue.BREACHER) == null, "Roster cannot change during an active expedition")
	expedition.inventory.add(preload("res://content/items/scrap.tres"), 9)
	expedition.inventory.add(preload("res://content/items/wafer.tres"), 3)
	var salvage_before: int = campaign.salvage
	_check(CampaignRules.complete_expedition(campaign, &"retreat") and campaign.salvage == salvage_before + 4 and campaign.data_wafers == 1, "Guaranteed retreat forfeits half each recovered reward using integer floor")
	_check(not CampaignRules.complete_expedition(campaign, &"retreat"), "Expedition rewards apply once")
	campaign.starting_cells = 1
	expedition = CampaignRules.deploy(campaign)
	expedition.inventory.add(preload("res://content/items/scrap.tres"), 6)
	expedition.inventory.add(preload("res://content/items/wafer.tres"), 2)
	expedition.boss_cleared = true
	salvage_before = campaign.salvage
	var data_before: int = campaign.data_wafers
	_check(CampaignRules.complete_expedition(campaign, &"success") and campaign.salvage == salvage_before + 6 and campaign.data_wafers == data_before + 2, "Boss extraction returns full rewards")
	expedition = CampaignRules.deploy(campaign)
	for deployed: CrewState in expedition.crew:
		deployed.dead = true
		deployed.health = 0
	expedition.failed = true
	_check(CampaignRules.complete_expedition(campaign, &"defeat") and campaign.party_ids.is_empty(), "Party defeat permanently removes dead crew from selection")
	var replacement: CrewState = CampaignRules.recruit_free(campaign, ContentCatalogue.BREACHER)
	_check(replacement != null and replacement.upgrade_health_bonus == 2 and CampaignRules.toggle_party(campaign, replacement.id), "Free upgraded recruitment keeps a campaign playable after total party loss")


func _test_save_round_trip() -> void:
	var campaign: CampaignState = CampaignRules.create_campaign()
	campaign.salvage = 77
	campaign.data_wafers = 4
	CampaignRules.buy_module(campaign, ContentCatalogue.MODULES[0].id)
	CampaignRules.equip_module(campaign, campaign.roster[0].id, ContentCatalogue.MODULES[0].id)
	var expedition: ExpeditionState = CampaignRules.deploy(campaign, 922337)
	ExpeditionRules.begin_travel(expedition, &"receiving")
	ExpeditionRules.arrive(expedition)
	var room: RoomDefinition = ExpeditionRules.begin_encounter(expedition)
	var seed_before: int = expedition.rooms[room.id].encounter_seed
	var text: String = JSON.stringify(SaveCodec.encode(campaign))
	var decoded: Dictionary = SaveCodec.decode(JSON.parse_string(text))
	_check(decoded.ok, "Versioned JSON campaign round trip validates")
	if decoded.ok:
		var loaded: CampaignState = decoded.state
		_check(loaded != campaign and loaded.roster[0] != campaign.roster[0] and loaded.roster[0].definition == campaign.roster[0].definition, "Loading creates new mutable records while reusing authored Resources")
		_check(loaded.salvage == 67 and loaded.data_wafers == 4 and loaded.roster[0].module_id == ContentCatalogue.MODULES[0].id, "Campaign currency and equipment survive JSON")
		_check(loaded.active_expedition != null and loaded.active_expedition.encounter_room == &"receiving" and not loaded.active_expedition.battle_active, "Battle checkpoint reloads at reserved encounter entry")
		_check(loaded.active_expedition.rooms[&"receiving"].encounter_seed == seed_before, "Encounter seed is serialized as an exact decimal string")
		loaded.roster[0].health -= 1
		_check(loaded.roster[0].health != campaign.roster[0].health, "Loaded runtime health does not alias live campaign health")
	var overflow_campaign: CampaignState = CampaignRules.create_campaign()
	var overflow_expedition: ExpeditionState = CampaignRules.deploy(overflow_campaign)
	overflow_expedition.inventory.add(ContentCatalogue.POWER_CELL, 34)
	overflow_expedition.pending_loot.append(ItemStack.new(ContentCatalogue.SCRAP, 40))
	var overflow_reload: Dictionary = SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(overflow_campaign))))
	_check(overflow_reload.ok and overflow_reload.state.active_expedition.pending_loot[0].quantity == 40,
		"Pending overflow may exceed item max_stack until the player resolves cargo")
	var invalid_stored_stack: Dictionary = SaveCodec.encode(overflow_campaign)
	invalid_stored_stack.campaign.active_expedition.inventory[0].quantity = 40
	_check(SaveCodec.decode(invalid_stored_stack).code == &"corrupt", "Stored inventory stacks still enforce the authored max_stack")
	var reward_campaign: CampaignState = CampaignRules.create_campaign()
	var reward_expedition: ExpeditionState = CampaignRules.deploy(reward_campaign)
	reward_expedition.inventory.add(ContentCatalogue.SCRAP, 8)
	CampaignRules.complete_expedition(reward_campaign, &"retreat")
	var rewarded_salvage: int = reward_campaign.salvage
	reward_campaign.roster[7].dead = true
	reward_campaign.roster[7].health = 0
	var reward_reload: Dictionary = SaveCodec.decode(JSON.parse_string(JSON.stringify(SaveCodec.encode(reward_campaign))))
	_check(reward_reload.ok and reward_reload.state.salvage == rewarded_salvage and reward_reload.state.active_expedition == null, "Completed-expedition rewards and consumed expedition survive reload exactly once")
	_check(not CampaignRules.complete_expedition(reward_reload.state, &"retreat") and reward_reload.state.salvage == rewarded_salvage, "Reload cannot apply completed expedition rewards again")
	_check(reward_reload.state.roster[7].dead and reward_reload.state.roster[7].health == 0, "Permanent death survives the JSON checkpoint")
	var unsupported: Dictionary = SaveCodec.encode(campaign)
	unsupported.version = 999
	_check(SaveCodec.decode(unsupported).code == &"unsupported", "Unsupported version is distinguished from damaged data")
	var corrupt: Dictionary = SaveCodec.encode(campaign)
	corrupt.campaign.roster[0].class_id = "missing_class"
	_check(SaveCodec.decode(corrupt).code == &"corrupt", "Unknown authored IDs reject the entire save before live state changes")
	corrupt = SaveCodec.encode(campaign)
	corrupt.campaign.roster[0].health = "not a number"
	_check(SaveCodec.decode(corrupt).code == &"corrupt", "Wrong JSON field types fail validation without partial reconstruction")
	var base: String = "user://hollow_signal_m8_test_%d" % Time.get_ticks_msec()
	var store: SaveStore = SaveStore.new(base)
	store.delete_all()
	_check(store.save_campaign(campaign).ok, "Verified temporary write installs the main checkpoint")
	campaign.salvage += 1
	_check(store.save_campaign(campaign).ok and store.inspect().backup.ok, "Second checkpoint preserves the prior known-good backup")
	var expected_backup_salvage: int = 67
	var backup: Dictionary = store.load_campaign(true)
	_check(backup.ok and backup.state.salvage == expected_backup_salvage, "Known-good backup loads the prior campaign")
	var main_file: FileAccess = FileAccess.open(store.main_path, FileAccess.WRITE)
	main_file.store_string("{ damaged")
	main_file.close()
	_check(store.load_campaign().code == &"corrupt" and store.load_campaign(true).ok, "Damaged main save exposes an explicit backup recovery path")
	_check(not store.save_campaign(campaign).ok, "Autosave refuses to overwrite a damaged main save")
	store.delete_all()


func _cargo_count(state: ExpeditionState) -> int:
	var total: int = 0
	for stack: ItemStack in state.inventory.stacks:
		total += stack.quantity
	for stack: ItemStack in state.pending_loot:
		total += stack.quantity
	return total


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		printerr("FAIL: ", description)
