class_name BattleController
extends Node
## Coordinates input/AI and timing; only CombatRules changes combat state.

signal events_resolved(events: Array[CombatEvent])
signal state_changed
signal setup_failed(reason: String)

enum Phase { PLAYER_INPUT, RESOLVING, ENEMY_TURN, FINISHED }

@export var battle_seed: int = 1729

var state: CombatState
var phase: Phase = Phase.FINISHED
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var enemy_timer: Timer = $EnemyDelay


func start_battle() -> void:
	enemy_timer.stop()
	rng.seed = battle_seed
	state = CombatRules.create_battle(ContentCatalogue.TEST_CREW, ContentCatalogue.TEST_ENEMY)
	if state == null:
		phase = Phase.FINISHED
		setup_failed.emit("Cannot start: check the actor Resources in content/actors.")
	else:
		phase = Phase.PLAYER_INPUT
	state_changed.emit()


func submit_player_action(action_id: StringName) -> bool:
	if phase != Phase.PLAYER_INPUT or state == null:
		return false
	var targets: Array[StringName] = []
	if action_id == &"attack":
		targets.append(&"enemy_1")
	var command: ActionCommand = ActionCommand.new(&"crew_1", action_id, targets, state.turn_number)
	if not CombatRules.validate_action(state, command).is_empty():
		return false
	phase = Phase.RESOLVING
	_apply(command)
	if state.outcome != &"ongoing":
		phase = Phase.FINISHED
	else:
		phase = Phase.ENEMY_TURN
		enemy_timer.start()
	state_changed.emit()
	return true


func _on_enemy_delay_timeout() -> void:
	if phase != Phase.ENEMY_TURN or state == null:
		return
	var legal: Array[ActionCommand] = CombatRules.get_legal_actions(state, state.active_actor_id)
	if legal.is_empty():
		phase = Phase.FINISHED
		setup_failed.emit("No legal enemy action. Restart the test battle.")
		state_changed.emit()
		return
	# The only opponent is known. Prefer a legal Attack, otherwise a legal Wait.
	var command: ActionCommand = legal[0]
	for candidate: ActionCommand in legal:
		if candidate.action_id == &"attack":
			command = candidate
			break
	phase = Phase.RESOLVING
	_apply(command)
	phase = Phase.PLAYER_INPUT if state.outcome == &"ongoing" else Phase.FINISHED
	state_changed.emit()


func _apply(command: ActionCommand) -> void:
	var events: Array[CombatEvent] = CombatRules.resolve_action(state, command, rng)
	# Presentation is immediate in M2; no animation or sound dependency.
	events_resolved.emit(events)
