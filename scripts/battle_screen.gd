extends "res://scripts/screen_navigation.gd"
## Reads state and event snapshots. Target buttons submit commands; never damage.

@onready var controller: BattleController = $BattleController
@onready var turn_label: Label = %TurnLabel
@onready var order_label: Label = %OrderLabel
@onready var status_label: Label = %Status
@onready var help_label: Label = %ActionHelp
@onready var strike_button: Button = %Strike
@onready var shot_button: Button = %Shot
@onready var third_button: Button = %Skill3
@onready var detail_label: Label = %SelectedDetail
@onready var encounter_button: Button = %Encounter
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
	strike_button.pressed.connect(_select_slot.bind(0))
	shot_button.pressed.connect(_select_slot.bind(1))
	third_button.pressed.connect(_select_slot.bind(2))
	encounter_button.pressed.connect(_switch_encounter)
	move_button.pressed.connect(select_action.bind(&"move"))
	wait_button.pressed.connect(_on_wait_pressed)
	for rank: int in range(1, 5):
		slot_button(ActorState.Team.CREW, rank).pressed.connect(_on_slot_pressed.bind(ActorState.Team.CREW, rank))
		slot_button(ActorState.Team.ENEMY, rank).pressed.connect(_on_slot_pressed.bind(ActorState.Team.ENEMY, rank))
	restart_battle()


func _switch_encounter() -> void:
	if _transition_pending:
		return
	var signal_patrol: bool = controller.enemy_definitions[2] != ContentCatalogue.CHORISTER
	controller.crew_definitions = ContentCatalogue.crew_party()
	controller.enemy_definitions = ContentCatalogue.enemy_party(signal_patrol)
	encounter_button.text = "Signal patrol / switch" if signal_patrol else "Boarding patrol / switch"
	restart_battle()


func _select_slot(index: int) -> void:
	var actor: ActorState = controller.state.get_actor(controller.state.active_actor_id) if controller.state != null else null
	if actor != null and index < actor.definition.abilities.size():
		select_action(actor.definition.abilities[index].id)


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
			&"healed":
				_append_log("%s heals %s for %d HP (now %d)." % [event.source_name, event.target_name, event.amount, event.health_after])
			&"strain_changed":
				_append_log("%s: %s strain %+d (now %d)." % [event.ability_name, event.target_name, event.amount, event.strain_after])
			&"status_applied":
				_append_log("%s: %s gains %s for %d turn starts." % [event.source_name, event.target_name, event.status_name, event.duration])
			&"status_expired":
				_append_log("%s: %s expired." % [event.target_name, event.status_name])
			&"dot_damage":
				_append_log("%s takes %d %s damage before acting (HP %d)." % [event.target_name, event.amount, event.status_name, event.health_after])
			&"displaced":
				_append_log("%s: %s shifts rank %d to %d. Turn order unchanged." % [event.ability_name, event.target_name, event.source_rank, event.target_rank])
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
	var acting: ActorState = state.get_actor(state.active_actor_id) if state != null else null
	var buttons: Array[Button] = [strike_button, shot_button, third_button]
	for index: int in range(buttons.size()):
		var ability: AbilityDefinition = acting.definition.abilities[index] if acting != null and index < acting.definition.abilities.size() else null
		buttons[index].visible = ability != null
		buttons[index].disabled = not can_act or ability == null or ability.id not in choices
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
		turn_text = "%s %s / Rank %d / %s" % [actor.short_name(), actor.definition.display_name, state.get_rank(actor.id),
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
	for button: Button in [strike_button, shot_button, third_button, wait_button]:
		if button.visible and not button.disabled:
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
	var status_labels: PackedStringArray = []
	var status_details: PackedStringArray = []
	for status: StatusState in actor.statuses:
		var symbol: String = ["P", "X", "D"][status.definition.kind]
		status_labels.append("%s%d" % [symbol, status.remaining])
		status_details.append("%s: %d turn starts left" % [status.definition.display_name, status.remaining])
	button.text = "Rank %d / %s\n%s\nHP %d/%d | Str %d\n%s\n%s" % [rank, actor.short_name(), actor.definition.display_name,
		actor.health, actor.definition.max_health, actor.strain, marker, " ".join(status_labels) if not status_labels.is_empty() else "—"]
	button.tooltip_text = "%s / %s / Speed %d. %s" % [actor.short_name(), actor.definition.display_name,
		actor.definition.speed, "Click to resolve the selected action." if not button.disabled else "Not a legal target for the selected action."]
	button.tooltip_text += "\n" + "\n".join(status_details)
	if actor.id == controller.state.active_actor_id:
		button.modulate = Color("ffd5a8")


func _refresh_help(actor: ActorState, can_act: bool) -> void:
	var lines: PackedStringArray = []
	var buttons: Array[Button] = [strike_button, shot_button, third_button]
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		var ability: AbilityDefinition = actor.definition.abilities[index] if actor != null and index < actor.definition.abilities.size() else null
		if ability == null:
			continue
		button.text = ability.display_name
		if ability.damage_max > 0:
			button.text += " / %d–%d" % [ability.damage_min, ability.damage_max]
		if ability.max_uses > 0:
			button.text += " / %d left" % (ability.max_uses - actor.uses.get(ability.id, 0))
		var reason: String = CombatRules.ability_reason(controller.state, actor.id, ability.id)
		if reason.is_empty():
			reason = "SELECTED: click a TARGET." if selected_action == ability.id and can_act else "Available."
			if not can_act:
				reason = "Actions locked until a crew turn."
		lines.append("%s: %s" % [ability.display_name, reason])
		button.tooltip_text = ability.description + "\n" + reason
	help_label.text = "\n".join(lines)
	var selected: AbilityDefinition = actor.definition.get_ability(selected_action) if actor != null else null
	detail_label.text = "Move: click an adjacent SWAP ally; this spends the acting crew member's turn."
	if selected != null:
		detail_label.text = selected.description
		if selected.damage_max > 0:
			var previews: PackedStringArray = []
			for command: ActionCommand in CombatRules.get_legal_actions(controller.state, actor.id):
				if command.action_id == selected.id:
					var target: ActorState = controller.state.get_actor(command.target_ids[0])
					previews.append("%s %d–%d" % [target.short_name(),
						mini(target.health, CombatRules.adjusted_damage(target, selected, selected.damage_min)),
						mini(target.health, CombatRules.adjusted_damage(target, selected, selected.damage_max))])
			detail_label.text += "\nTarget HP loss: " + "; ".join(previews)
	elif actor == null:
		detail_label.text = "Battle ended. Restart or switch patrol for a fresh battle."
