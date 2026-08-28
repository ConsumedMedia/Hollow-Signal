extends "res://scripts/screen_navigation.gd"
## Reads state and event snapshots. Target buttons submit commands; never damage.
signal expedition_battle_closed
var expedition_mode: bool = false

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
@onready var overcharge_button: CheckButton = %Overcharge
@onready var power_label: Label = %PowerLabel
@onready var next_button: Button = %NextBattle
@onready var rules_label: Label = %RulesLabel
@onready var stage: PlaceholderStage = $Margin/Layout/Stage

var selected_action: StringName = &""
var _view_turn: int = -1
var _log_lines: PackedStringArray = []
var _setup_error: String = ""
var _drill_active: bool = false
var _seed_before_drill: int = 1729


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
	overcharge_button.toggled.connect(_on_overcharge_toggled)
	next_button.pressed.connect(_next_battle)
	(%Drill as Button).pressed.connect(_start_drill)
	(%ReturnToRoom as Button).pressed.connect(_return_to_room)
	for rank: int in range(1, 5):
		slot_button(ActorState.Team.CREW, rank).pressed.connect(_on_slot_pressed.bind(ActorState.Team.CREW, rank))
		slot_button(ActorState.Team.ENEMY, rank).pressed.connect(_on_slot_pressed.bind(ActorState.Team.ENEMY, rank))
	if expedition_mode:
		for button: Button in [encounter_button, restart_button, next_button, %Drill, %BackToHub, %MainMenu]:
			button.hide()
		(%ReturnToRoom as Button).show()
		$Margin/Layout/Footer.text = "Expedition battle: health, strain, power and deaths carry back to the room. Retreat arrives in milestone 7."
		_log_lines = ["Expedition encounter. Defeat loses the deployed crew; victory returns survivors to the ship."]
		controller.start_battle(true)
	else:
		restart_battle()


func _return_to_room() -> void:
	if expedition_mode and not _transition_pending and controller.phase == BattleController.Phase.FINISHED:
		_transition_pending = true
		expedition_battle_closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if expedition_mode and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)


func _on_overcharge_toggled(_pressed: bool) -> void:
	_refresh()


func _start_drill() -> void:
	if _transition_pending:
		return
	if not _drill_active:
		_seed_before_drill = controller.battle_seed
	_drill_active = true
	_view_turn = -1
	_setup_error = ""
	selected_action = &""
	_log_lines = ["DRILL: new test crew. C1 downed, C3 Shaken, one Overcharge left. Medic acts first.",
		"Field patch -> C1 revives them. Steady voice -> C3 reduces strain. Fresh expedition resets the drill."]
	encounter_button.text = "Boarding patrol / switch"
	controller.start_vulnerability_drill()


func _next_battle() -> void:
	if _transition_pending or controller.state == null or controller.state.outcome != &"victory":
		return
	_view_turn = -1
	if controller.next_test_battle():
		_log_lines = ["Next test room: health, strain, Shaken, deaths, ranks and power carried forward.",
			"Temporary statuses and healing uses reset. Restart explicitly creates a fresh test expedition."]
		_refresh()


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
	if _drill_active:
		controller.battle_seed = _seed_before_drill
		_drill_active = false
	_log_lines = ["Choose an attack, then click a TARGET. Move: choose an adjacent ally marked SWAP.",
		"Downed crew can be healed. Further damage kills them. No conscious crew means everyone is lost."]
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
		controller.submit_player_action(selected_action, target.id, _view_turn, overcharge_button.button_pressed)


func _present_events(events: Array[CombatEvent]) -> void:
	for event: CombatEvent in events:
		match event.kind:
			&"power_spent":
				_append_log("OVERCHARGE: %d power spent; %d left." % [event.amount, event.power_after])
			&"downed":
				_append_log("%s DOWNED: cannot act. Heal now; further damage kills permanently." % event.target_name)
			&"died":
				_append_log("%s DEAD: permanently lost from this expedition." % event.target_name)
			&"revived":
				_append_log("%s revived. Acts at its next unused initiative slot." % event.target_name)
			&"recovered":
				_append_log("%s survived downed and recovers to %d HP." % [event.target_name, event.health_after])
			&"shaken":
				_append_log("%s SHAKEN: reduced damage until strain falls below %d." % [event.target_name, controller.state.balance.shaken_clear_below])
			&"shaken_cleared":
				_append_log("%s is no longer Shaken." % event.target_name)
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
				if expedition_mode:
					_append_log("VICTORY. Return to room with your survivors." if event.outcome == &"victory" else "DEFEAT. All deployed crew lost. Return to the ship summary.")
				else:
					_append_log("VICTORY. Next battle keeps survivors; Restart creates fresh crew." if event.outcome == &"victory"
						else "DEFEAT. All deployed crew are lost. Restart creates a NEW test expedition.")


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
			overcharge_button.set_pressed_no_signal(false)
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
	var selected: AbilityDefinition = acting.definition.get_ability(selected_action) if acting != null else null
	overcharge_button.disabled = not can_act or selected == null or selected.damage_max <= 0 or state.expedition.power < state.balance.overcharge_cost
	if overcharge_button.disabled:
		overcharge_button.set_pressed_no_signal(false)
	next_button.disabled = state == null or state.outcome != &"victory"
	(%ReturnToRoom as Button).disabled = controller.phase != BattleController.Phase.FINISHED
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
	var balance: CombatBalance = state.balance
	overcharge_button.text = "Overcharge %s / %d power / +%d%%" % ["ON" if overcharge_button.button_pressed else "OFF", balance.overcharge_cost, roundi((balance.overcharge_multiplier - 1.0) * 100.0)]
	overcharge_button.tooltip_text = "Select a damaging crew ability on your turn. Power is spent only when you click a legal target; fixed Scorch ticks are unchanged."
	var dead_names: PackedStringArray = []
	for member: CrewState in state.expedition.crew:
		if member.dead:
			dead_names.append(String(member.id).replace("crew_", "C"))
	power_label.text = "POWER %d/%d | %sRoom strain +%d%s" % [state.expedition.power, balance.power_max,
		"LOW: " if state.expedition.power < balance.power_safe_threshold else "",
		CombatRules.room_strain(state.expedition.power), " | DEAD: " + ", ".join(dead_names) if not dead_names.is_empty() else ""]
	power_label.tooltip_text = "Room entry: +0 strain at %d+ power; +%d at %d–%d; +%d below %d. Zero power does not end an expedition." % [
		balance.power_safe_threshold, balance.medium_power_strain, balance.power_low_threshold, balance.power_safe_threshold - 1,
		balance.low_power_strain, balance.power_low_threshold]
	rules_label.text = "0 HP: DOWNED; heal to revive, further damage kills. No conscious crew: all lost.\nStrain %d: SHAKEN (−%d%% damage), clears below %d. P/X/D: Protected / Exposed / Scorch." % [
		balance.shaken_threshold, roundi((1.0 - balance.shaken_damage_multiplier) * 100.0), balance.shaken_clear_below]
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
		if queued != null and queued.is_conscious():
			order.append("%s:%d" % [queued.short_name(), state.initiative_scores[queued.id]])
	order_label.text = "Remaining order (Speed + d6): " + " > ".join(order) if actor != null else "Battle ended. No further actions."
	_refresh_help(actor, can_act)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null or (focus is Button and (focus as Button).disabled):
		if can_act:
			_focus_action()
		elif not expedition_mode:
			restart_button.grab_focus()
		elif not (%ReturnToRoom as Button).disabled:
			(%ReturnToRoom as Button).grab_focus()


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
	if actor.is_downed():
		marker = "DOWNED"
	for command: ActionCommand in legal:
		if can_act and command.overcharge == overcharge_button.button_pressed and command.action_id == selected_action and actor.id in command.target_ids:
			button.disabled = false
			marker = "SWAP" if selected_action == &"move" else "TARGET"
			if actor.is_downed():
				marker += " / DOWNED"
			break
	var status_labels: PackedStringArray = []
	var status_details: PackedStringArray = []
	if actor.shaken:
		status_labels.append("SHAKEN")
	if actor.is_downed():
		status_details.append("DOWNED: cannot act; healing revives; any further positive damage kills.")
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
				if command.action_id == selected.id and command.overcharge == overcharge_button.button_pressed:
					var target: ActorState = controller.state.get_actor(command.target_ids[0])
					previews.append("%s %d–%d" % [target.short_name(),
						mini(target.health, CombatRules.adjusted_damage(target, selected, selected.damage_min, actor, command.overcharge)),
						mini(target.health, CombatRules.adjusted_damage(target, selected, selected.damage_max, actor, command.overcharge))])
			detail_label.text += "\nTarget HP loss: " + "; ".join(previews)
	elif actor == null:
		detail_label.text = "Battle ended. Return to room to keep the resolved expedition state." if expedition_mode else "Battle ended. Next battle keeps survivors; Fresh expedition or patrol switch starts new test crew."
