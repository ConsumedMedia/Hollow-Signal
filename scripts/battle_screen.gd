extends "res://scripts/screen_navigation.gd"
## Reads results and presents them. Never rolls or applies damage.

@onready var controller: BattleController = $BattleController
@onready var turn_label: Label = %TurnLabel
@onready var crew_label: Label = %CrewLabel
@onready var enemy_label: Label = %EnemyLabel
@onready var status_label: Label = %Status
@onready var attack_button: Button = %Attack
@onready var wait_button: Button = %Wait
@onready var restart_button: Button = %Restart
@onready var stage: PlaceholderStage = $Margin/Layout/Stage

var _log_lines: PackedStringArray = []


func _ready() -> void:
	super._ready()
	controller.events_resolved.connect(_present_events)
	controller.state_changed.connect(_refresh)
	controller.setup_failed.connect(_show_setup_error)
	restart_battle()


func restart_battle() -> void:
	if _transition_pending:
		return
	_log_lines.clear()
	_log_lines.append("Attack the Sentry, or Wait to skip your action. The enemy responds automatically.")
	_log_lines.append("This test has no permanent losses. Restart reuses the same seed.")
	controller.start_battle()
	if controller.state != null:
		attack_button.grab_focus()


func _on_attack_pressed() -> void:
	if not _transition_pending:
		controller.submit_player_action(&"attack")


func _on_wait_pressed() -> void:
	if not _transition_pending:
		controller.submit_player_action(&"wait")


func _present_events(events: Array[CombatEvent]) -> void:
	for event: CombatEvent in events:
		match event.kind:
			&"damage":
				_append_log("%s hits %s for %d damage. Target HP: %d." % [
					_actor_name(event.source_id), _actor_name(event.target_id), event.amount, event.health_after])
			&"wait":
				_append_log("%s waits and spends the action." % _actor_name(event.source_id))
			&"defeated":
				_append_log("%s is defeated." % _actor_name(event.target_id))
			&"battle_ended":
				_append_log("VICTORY. Restart to replay the same seed." if event.outcome == &"victory" \
					else "DEFEAT. Restart for a fresh attempt with the same seed.")


func _actor_name(actor_id: StringName) -> String:
	return controller.state.get_actor(actor_id).definition.display_name


func _append_log(message: String) -> void:
	_log_lines.append(message)
	while _log_lines.size() > 3:
		_log_lines.remove_at(0)


func _show_setup_error(reason: String) -> void:
	_log_lines = [reason]
	turn_label.text = "Battle setup error"


func _refresh() -> void:
	status_label.text = "\n".join(_log_lines)
	var state: CombatState = controller.state
	if state == null:
		attack_button.disabled = true
		wait_button.disabled = true
		return
	var crew: ActorState = state.get_actor(&"crew_1")
	var enemy: ActorState = state.get_actor(&"enemy_1")
	crew_label.text = _actor_text("CREW", crew)
	enemy_label.text = _actor_text("ENEMY", enemy)
	stage.crew_defeated = not crew.is_conscious()
	stage.enemy_defeated = not enemy.is_conscious()
	stage.queue_redraw()
	attack_button.text = "Attack Sentry  /  %d–%d damage" % [crew.definition.damage_min, crew.definition.damage_max]
	wait_button.text = "Wait  /  skip action"
	var can_act: bool = controller.phase == BattleController.Phase.PLAYER_INPUT
	attack_button.disabled = not can_act
	wait_button.disabled = not can_act
	var turn_text: String = "Your turn" if can_act else "Enemy turn — actions locked"
	if state.outcome != &"ongoing":
		turn_text = "VICTORY" if state.outcome == &"victory" else "DEFEAT"
	turn_label.text = "Round %d  /  %s  /  Seed %d" % [state.round_number, turn_text, controller.battle_seed]
	attack_button.tooltip_text = "Always hits the opposing Sentry." if can_act else "Wait for your turn, or restart after the battle ends."
	wait_button.tooltip_text = "Consumes your action without damage or healing."
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or (focus is Button and (focus as Button).disabled):
		if can_act:
			attack_button.grab_focus()
		elif state.outcome != &"ongoing":
			restart_button.grab_focus()


func _actor_text(side_name: String, actor: ActorState) -> String:
	var condition: String = "  /  DEFEATED" if not actor.is_conscious() else ""
	return "%s / %s%s\nHP %d / %d  ·  Attack %d–%d" % [side_name, actor.definition.display_name,
		condition, actor.health, actor.definition.max_health, actor.definition.damage_min, actor.definition.damage_max]
