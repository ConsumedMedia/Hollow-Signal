extends "res://scripts/screen_navigation.gd"
## Reads state and event snapshots. Target buttons submit commands; never damage.

@onready var controller: BattleController = $BattleController
@onready var turn_label: Label = %TurnLabel
@onready var order_label: Label = %OrderLabel
@onready var status_label: Label = %Status
@onready var help_label: Label = %ActionHelp
@onready var strike_button: Button = %Strike
@onready var shot_button: Button = %Shot
@onready var move_button: Button = %Move
@onready var wait_button: Button = %Wait
@onready var restart_button: Button = %Restart
@onready var stage: PlaceholderStage = $Margin/Layout/Stage

var selected_action: StringName = &""
var _view_turn: int = -1
var _log_lines: PackedStringArray = []
var _setup_error: String = ""


func _ready() -> void:
	super._ready()
	controller.events_resolved.connect(_present_events)
	controller.state_changed.connect(_refresh)
	controller.setup_failed.connect(_show_setup_error)
	strike_button.pressed.connect(select_action.bind(&"strike"))
	shot_button.pressed.connect(select_action.bind(&"shot"))
	move_button.pressed.connect(select_action.bind(&"move"))
	wait_button.pressed.connect(_on_wait_pressed)
	for rank: int in range(1, 5):
		slot_button(ActorState.Team.CREW, rank).pressed.connect(_on_slot_pressed.bind(ActorState.Team.CREW, rank))
		slot_button(ActorState.Team.ENEMY, rank).pressed.connect(_on_slot_pressed.bind(ActorState.Team.ENEMY, rank))
	restart_battle()


func slot_button(team: ActorState.Team, rank: int) -> Button:
	var prefix: String = "Crew" if team == ActorState.Team.CREW else "Enemy"
	return get_node("%%%sRank%d" % [prefix, rank]) as Button


func restart_battle() -> void:
	if _transition_pending:
		return
	_view_turn = -1
	selected_action = &""
	_setup_error = ""
	_log_lines = ["Choose an attack, then click a TARGET. Move: choose an adjacent ally marked SWAP.",
		"Rank 1 is nearest the opposition. Each actor acts once per round. No permanent loss yet."]
	controller.start_battle()
	if controller.phase == BattleController.Phase.PLAYER_INPUT:
		_focus_action()


func select_action(action_id: StringName) -> void:
	if _transition_pending or controller.phase != BattleController.Phase.PLAYER_INPUT:
		return
	for command: ActionCommand in CombatRules.get_legal_actions(controller.state, controller.state.active_actor_id):
		if command.action_id == action_id:
			selected_action = action_id
			_refresh()
			return


func _on_wait_pressed() -> void:
	if not _transition_pending:
		controller.submit_player_action(&"wait", &"", _view_turn)


func _on_slot_pressed(team: ActorState.Team, rank: int) -> void:
	if _transition_pending or selected_action.is_empty():
		return
	var target: ActorState = controller.state.actor_at(team, rank)
	if target != null:
		controller.submit_player_action(selected_action, target.id, _view_turn)


func _present_events(events: Array[CombatEvent]) -> void:
	for event: CombatEvent in events:
		match event.kind:
			&"damage":
				_append_log("%s hits %s for %d damage. Target HP: %d." % [
					event.source_name, event.target_name, event.amount, event.health_after])
			&"wait":
				_append_log("%s waits and spends the action." % event.source_name)
			&"moved":
				_append_log("%s swaps rank %d with %s at rank %d. Action spent." % [
					event.source_name, event.source_rank, event.target_name, event.target_rank])
			&"defeated":
				_append_log("%s is defeated and removed." % event.target_name)
			&"ranks_compacted":
				_append_log("%s ranks close up." % ("Crew" if event.team == ActorState.Team.CREW else "Enemy"))
			&"round_started":
				_append_log("Round %d: initiative rerolled (Speed + 1–6)." % event.round_number)
			&"battle_ended":
				_append_log("VICTORY. Restart to replay the same seed." if event.outcome == &"victory"
					else "DEFEAT. Restart for a fresh attempt with the same seed.")


func _append_log(message: String) -> void:
	_log_lines.append(message)
	while _log_lines.size() > 3:
		_log_lines.remove_at(0)


func _show_setup_error(reason: String) -> void:
	_setup_error = reason
	_log_lines = [reason]


func _refresh() -> void:
	status_label.text = "\n".join(_log_lines)
	var state: CombatState = controller.state
	var can_act: bool = controller.phase == BattleController.Phase.PLAYER_INPUT and _setup_error.is_empty()
	var legal: Array[ActionCommand] = []
	if state != null:
		legal = CombatRules.get_legal_actions(state, state.active_actor_id)
		if _view_turn != state.turn_number:
			_view_turn = state.turn_number
			selected_action = &""
			for command: ActionCommand in legal:
				if command.action_id not in [&"move", &"wait"]:
					selected_action = command.action_id
					break
	var choices: Array[StringName] = []
	for command: ActionCommand in legal:
		if command.action_id not in choices:
			choices.append(command.action_id)
	strike_button.disabled = not can_act or &"strike" not in choices
	shot_button.disabled = not can_act or &"shot" not in choices
	move_button.disabled = not can_act or &"move" not in choices
	wait_button.disabled = not can_act or &"wait" not in choices
	for rank: int in range(1, 5):
		_refresh_slot(ActorState.Team.CREW, rank, legal, can_act)
		_refresh_slot(ActorState.Team.ENEMY, rank, legal, can_act)
	if state == null:
		turn_label.text = "Battle setup error"
		return
	stage.crew_ids = state.crew_ranks.duplicate()
	stage.enemy_ids = state.enemy_ranks.duplicate()
	stage.active_id = state.active_actor_id
	stage.queue_redraw()
	var actor: ActorState = state.get_actor(state.active_actor_id)
	var turn_text: String = "VICTORY" if state.outcome == &"victory" else "DEFEAT"
	if actor != null:
		turn_text = "%s / Rank %d / %s" % [actor.short_name(), state.get_rank(actor.id),
			"Your turn" if can_act else "Actions locked"]
	if not _setup_error.is_empty():
		turn_text = "Battle setup error"
	turn_label.text = "Round %d / %s / Seed %d" % [state.round_number, turn_text, controller.battle_seed]
	var order: PackedStringArray = []
	for index: int in range(state.turn_cursor, state.round_order.size()):
		var queued: ActorState = state.get_actor(state.round_order[index])
		if queued != null:
			order.append("%s:%d" % [queued.short_name(), state.initiative_scores[queued.id]])
	order_label.text = "Remaining order (Speed + d6): " + " > ".join(order) if actor != null else "Battle ended. No further actions."
	_refresh_help(actor, can_act)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or (focus is Button and (focus as Button).disabled):
		if can_act:
			_focus_action()
		else:
			restart_button.grab_focus()


func _focus_action() -> void:
	for button: Button in [strike_button, shot_button, wait_button]:
		if not button.disabled:
			button.grab_focus()
			return


func _refresh_slot(team: ActorState.Team, rank: int, legal: Array[ActionCommand], can_act: bool) -> void:
	var button: Button = slot_button(team, rank)
	var actor: ActorState = controller.state.actor_at(team, rank) if controller.state != null else null
	button.disabled = true
	button.modulate = Color.WHITE
	if actor == null:
		button.text = "Rank %d\nEMPTY\n—" % rank
		button.tooltip_text = "No actor occupies this rank."
		return
	var marker: String = "ACTING" if actor.id == controller.state.active_actor_id else "Standing"
	for command: ActionCommand in legal:
		if can_act and command.action_id == selected_action and actor.id in command.target_ids:
			button.disabled = false
			marker = "SWAP" if selected_action == &"move" else "TARGET"
			break
	button.text = "Rank %d / %s\nHP %d/%d\n%s" % [rank, actor.short_name(), actor.health, actor.definition.max_health, marker]
	button.tooltip_text = "%s / %s / Speed %d. %s" % [actor.short_name(), actor.definition.display_name,
		actor.definition.speed, "Click to resolve the selected action." if not button.disabled else "Not a legal target for the selected action."]
	if actor.id == controller.state.active_actor_id:
		button.modulate = Color("ffd5a8")


func _refresh_help(actor: ActorState, can_act: bool) -> void:
	var lines: PackedStringArray = []
	for ability_id: StringName in [&"strike", &"shot"]:
		var button: Button = strike_button if ability_id == &"strike" else shot_button
		var name_text: String = "Close strike" if ability_id == &"strike" else "Covering shot"
		var ability: AbilityDefinition = actor.definition.get_ability(ability_id) if actor != null else null
		button.text = name_text
		if ability != null:
			button.text += " / %d–%d" % [ability.damage_min, ability.damage_max]
		var reason: String = CombatRules.ability_reason(controller.state, actor.id, ability_id) if actor != null else "Battle ended."
		if reason.is_empty():
			reason = "Selected: click a TARGET." if selected_action == ability_id and can_act else "Available."
			if not can_act:
				reason = "Actions locked until a crew turn."
		lines.append("%s: %s" % [name_text, reason])
		button.tooltip_text = reason
	lines.append("Move selected: click SWAP on an adjacent ally." if selected_action == &"move" and can_act
		else "Move swaps adjacent allies and spends this actor's action. Wait is always available on your turn.")
	help_label.text = "\n".join(lines)
