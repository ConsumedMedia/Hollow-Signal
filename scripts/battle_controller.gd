class_name BattleController
extends Node
## Input/AI and pacing only; CombatRules owns gameplay changes.

signal events_resolved(events: Array[CombatEvent])
signal state_changed
signal setup_failed(reason: String)

enum Phase { PLAYER_INPUT, RESOLVING, ENEMY_TURN, FINISHED }

@export var battle_seed: int = 1729

var state: CombatState
var expedition: ExpeditionState
var phase: Phase = Phase.FINISHED
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var crew_definitions: Array[ActorDefinition] = ContentCatalogue.crew_party()
var enemy_definitions: Array[ActorDefinition] = ContentCatalogue.enemy_party()
var _generation: int = 0
var _last_input_frame: int = -1

@onready var enemy_timer: Timer = $EnemyDelay


func start_battle(keep_expedition: bool = false) -> void:
	_generation += 1
	enemy_timer.stop()
	_last_input_frame = -1
	rng.seed = battle_seed
	if not keep_expedition:
		expedition = null
	state = CombatRules.create_battle(crew_definitions, enemy_definitions, rng, expedition)
	if state == null:
		phase = Phase.FINISHED
		setup_failed.emit("Cannot start: check the actor and ability Resources in content.")
		state_changed.emit()
		return
	expedition = state.expedition
	_sync_phase()


func next_test_battle() -> bool:
	if state == null or state.outcome != &"victory" or not CombatRules.traverse_test_corridor(expedition):
		return false
	start_battle(true)
	return true


func start_vulnerability_drill() -> void:
	# Explicit test fixture, not a normal expedition starting condition.
	crew_definitions = ContentCatalogue.crew_party()
	enemy_definitions = ContentCatalogue.enemy_party()
	battle_seed = 20
	expedition = CombatRules.new_expedition(crew_definitions)
	expedition.power = CombatRules.BALANCE.overcharge_cost
	expedition.crew[0].health = 0
	expedition.crew[2].strain = CombatRules.BALANCE.shaken_threshold
	expedition.crew[2].shaken = true
	start_battle(true)


func submit_player_action(action_id: StringName, target_id: StringName, expected_turn: int, overcharge: bool = false) -> bool:
	if phase != Phase.PLAYER_INPUT or state == null or _last_input_frame == Engine.get_process_frames():
		return false
	var targets: Array[StringName] = []
	if not target_id.is_empty():
		targets.append(target_id)
	var command: ActionCommand = ActionCommand.new(state.active_actor_id, action_id, targets, expected_turn, overcharge)
	if not CombatRules.validate_action(state, command).is_empty():
		return false
	_last_input_frame = Engine.get_process_frames()
	_apply(command)
	return true


func retreat() -> bool:
	if phase != Phase.PLAYER_INPUT or state == null or _last_input_frame == Engine.get_process_frames():
		return false
	var events: Array[CombatEvent] = CombatRules.retreat(state)
	if events.is_empty():
		return false
	_last_input_frame = Engine.get_process_frames()
	phase = Phase.FINISHED
	events_resolved.emit(events)
	state_changed.emit()
	return true


func _on_enemy_delay_timeout() -> void:
	if phase != Phase.ENEMY_TURN or state == null:
		return
	var command: ActionCommand = EnemyPolicy.choose_action(state)
	if command == null:
		phase = Phase.FINISHED
		setup_failed.emit("No legal enemy action. Restart the test battle.")
		state_changed.emit()
		return
	_apply(command)


func _apply(command: ActionCommand) -> void:
	phase = Phase.RESOLVING
	var events: Array[CombatEvent] = CombatRules.resolve_action(state, command, rng)
	events_resolved.emit(events)
	state_changed.emit()
	_finish_resolution.call_deferred(_generation)


func _finish_resolution(generation: int) -> void:
	if generation == _generation:
		_sync_phase()


func _sync_phase() -> void:
	if state.outcome != &"ongoing":
		phase = Phase.FINISHED
	elif state.get_actor(state.active_actor_id).side == ActorState.Team.CREW:
		phase = Phase.PLAYER_INPUT
	else:
		phase = Phase.ENEMY_TURN
		enemy_timer.start()
	state_changed.emit()
