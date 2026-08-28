extends SceneTree
## Setup and battle integration checks. No third-party test framework.

const ErrorMonitor = preload("res://tests/engine_error_monitor.gd")

const MENU: String = "res://scenes/main_menu.tscn"
const HUB: String = "res://scenes/hub.tscn"
const BATTLE: String = "res://scenes/battle_test.tscn"

var _failures: int = 0
var _checks: int = 0
var _monitor: ErrorMonitor = ErrorMonitor.new()


func _initialize() -> void:
	OS.add_logger(_monitor)
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("SETUP SMOKE: timed out before completion")
		quit(1))
	var version: Dictionary = Engine.get_version_info()
	_check(version.major == 4 and version.minor == 7 and version.patch == 2, "Pinned Godot 4.7.2")
	_check(not OS.has_feature("mono"), "Standard build, no .NET dependency")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer configured")
	_check(root.content_scale_size == Vector2i(1920, 1080), "1920x1080 design resolution")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Proportional scaling with letterboxing")
	for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_focus_next", &"ui_up", &"ui_down", &"toggle_fullscreen"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Input binding: %s" % action)

	# Exercise each scene at both acceptance resolutions and a non-16:9 size.
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 900)]:
		root.size = window_size
		for scene_path: String in [MENU, HUB, BATTLE]:
			await _open(scene_path)
			_check_layout(scene_path, window_size)
			if "--capture" in OS.get_cmdline_user_args():
				await _capture(scene_path, window_size)

	await _open(MENU)
	var new_game: Button = current_scene.get_node("%NewGame") as Button
	new_game.pressed.emit()
	new_game.pressed.emit()
	# A different same-frame request must also be ignored while replacing a scene.
	(current_scene.get_node("%BattleTest") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == HUB, "New Game opens hub once, despite duplicate input")
	(current_scene.get_node("%OpenBattleTest") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == BATTLE, "Hub opens battle test")
	(current_scene.get_node("%BackToHub") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == HUB, "Battle back button opens hub")
	(current_scene.get_node("%MainMenu") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == MENU, "Hub main menu button works")
	(current_scene.get_node("%BattleTest") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == BATTLE, "Menu opens battle test directly")
	(current_scene.get_node("%MainMenu") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == MENU, "Battle main menu button works")

	await _open(BATTLE)
	await _press_key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == HUB, "Escape returns battle to hub")
	await _press_key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == MENU, "Escape returns hub to menu")
	await _press_key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == MENU, "Escape at menu does not quit")
	await _press_key(KEY_ENTER)
	_check(current_scene.scene_file_path == HUB, "Enter activates the initially focused New Game button")
	await _open(MENU)
	await _press_key(KEY_TAB)
	_check(root.gui_get_focus_owner() == current_scene.get_node("%BattleTest"), "Tab advances focus")
	await _press_key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == current_scene.get_node("%NewGame"), "Shift+Tab returns focus")
	await _press_key(KEY_DOWN)
	_check(root.gui_get_focus_owner() == current_scene.get_node("%BattleTest"), "Arrow key advances focus")
	await _click_button(current_scene.get_node("%NewGame") as Button)
	_check(current_scene.scene_file_path == HUB, "Mouse input reaches New Game through the GUI")
	if DisplayServer.get_name() != "headless":
		await _press_key(KEY_F11)
		_check(root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "F11 enters fullscreen")
		await _press_key(KEY_F11)
		_check(root.mode == Window.MODE_WINDOWED, "F11 returns to windowed mode")

	await _test_battle_flow()
	_check(_monitor.error_count() == 0, "No engine errors during scene checks")
	# Optional negative self-test proves this runner exits unsuccessfully.
	if "--self-test-failure" in OS.get_cmdline_user_args():
		_check(false, "Intentional failure to verify exit code")
	print("SETUP SMOKE: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_battle_flow() -> void:
	root.size = Vector2i(1280, 720)
	await _open(BATTLE)
	var controller: BattleController = current_scene.get_node("BattleController") as BattleController
	controller.enemy_timer.wait_time = 0.01
	await _await_player(controller)
	var state: CombatState = controller.state
	print("M3 DEFAULT ORDER: ", state.round_order, " / ", state.initiative_scores)
	_check(state.actors.size() == 8 and state.crew_ranks.size() == 4 and state.enemy_ranks.size() == 4, "UI starts with four actors on each side")
	_check((current_scene.get_node("%TurnLabel") as Label).text.contains(state.get_actor(state.active_actor_id).short_name()), "Current actor identified in header")
	_check((current_scene.get_node("%OrderLabel") as Label).text.contains("Speed + d6"), "Initiative queue visible")
	_check((current_scene.get_node("%Wait") as Button).disabled == false, "Wait enabled on crew turns")
	_check(root.gui_get_focus_owner() == current_scene.get_node("%Shot"), "Initial keyboard focus selects the usable rear attack")
	var initial_rng: int = controller.rng.state
	var initial_order: Array[StringName] = state.round_order.duplicate()
	var attack_command: ActionCommand = _first_attack(state)
	var target: ActorState = state.get_actor(attack_command.target_ids[0])
	current_scene.call("select_action", attack_command.action_id)
	var target_button: Button = _slot(target.side, state.get_rank(target.id))
	_check(not target_button.disabled and target_button.text.contains("TARGET"), "Legal attack targets are clickable and labelled")
	var bad_target: Button = _slot(ActorState.Team.CREW, state.get_rank(state.active_actor_id))
	bad_target.pressed.emit()
	_check(state.turn_number == 0, "Illegal target signal cannot change battle state")
	# Repeated signals are stronger than clicks: even disabled buttons can emit.
	target_button.pressed.emit()
	var first_damage: int = 20 - target.health
	target_button.pressed.emit()
	(current_scene.get_node("%Wait") as Button).pressed.emit()
	_check(state.turn_number == 1 and controller.phase == BattleController.Phase.RESOLVING, "Same-frame input resolves one action even before another crew turn")
	_check((current_scene.get_node("%Strike") as Button).disabled and (current_scene.get_node("%Wait") as Button).disabled, "All actions lock while resolving")
	_check((current_scene.get_node("%Status") as Label).text.contains("%d damage" % first_damage), "Damage snapshot reaches combat log")
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	await _settle()
	_check(controller.state.turn_number == 0 and controller.rng.state == initial_rng and controller.state.round_order == initial_order, "Restart cancels deferred resolution and repeats initiative")
	# Real GUI mouse input reaches an enemy card after selection.
	attack_command = _first_attack(controller.state)
	current_scene.call("select_action", attack_command.action_id)
	target = controller.state.get_actor(attack_command.target_ids[0])
	await _click_button(_slot(target.side, controller.state.get_rank(target.id)))
	_check(20 - target.health == first_damage, "GUI target click repeats the first damage roll after restart")
	await _await_player(controller)

	# Reach a boundary between front and rear without overriding rules.
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	for attempt: int in range(16):
		await _await_player(controller)
		if controller.state.get_rank(controller.state.active_actor_id) in [2, 3]:
			break
		(current_scene.get_node("%Wait") as Button).pressed.emit()
		await _settle()
	state = controller.state
	var mover: StringName = state.active_actor_id
	var from_rank: int = state.get_rank(mover)
	var to_rank: int = 3 if from_rank == 2 else 2
	var ally: ActorState = state.actor_at(ActorState.Team.CREW, to_rank)
	var order_before: Array[StringName] = state.round_order.duplicate()
	var turn_before: int = state.turn_number
	var before_strike: bool = CombatRules.ability_reason(state, mover, &"strike").is_empty()
	(current_scene.get_node("%Move") as Button).pressed.emit()
	_check(not _slot(ActorState.Team.CREW, to_rank).disabled and _slot(ActorState.Team.CREW, to_rank).text.contains("SWAP"), "Move highlights adjacent allies")
	_check(_slot(ActorState.Team.CREW, from_rank).disabled and _slot(ActorState.Team.ENEMY, 1).disabled, "Move disables self and opposing targets")
	await _check_outcome_layout("battle_move")
	_slot(ActorState.Team.CREW, to_rank).pressed.emit()
	await _settle()
	_check(state.get_rank(mover) == to_rank and state.get_rank(ally.id) == from_rank, "UI swap changes both ranks")
	_check(state.turn_number == turn_before + 1 and state.round_order == order_before, "UI swap consumes one turn and keeps the round queue")
	_check(CombatRules.ability_reason(state, mover, &"strike").is_empty() != before_strike, "Front/rear crossing immediately changes ability legality")
	_check((current_scene.get_node("%Status") as Label).text.contains("swaps rank"), "Move event explains action cost")
	await _await_player(controller)
	var rank: int = state.get_rank(state.active_actor_id)
	_check((current_scene.get_node("%Strike") as Button).disabled == (rank > 2) and (current_scene.get_node("%Shot") as Button).disabled == (rank <= 2), "Displayed skill availability follows the current rank")
	_check((current_scene.get_node("%ActionHelp") as Label).text.contains("Needs actor ranks"), "Disabled skill reason is visible without hovering")
	await _check_outcome_layout("battle_moved")

	# Restart while the timer for an enemy is pending.
	for attempt: int in range(16):
		if controller.phase == BattleController.Phase.ENEMY_TURN:
			break
		controller.enemy_timer.wait_time = 0.4
		(current_scene.get_node("%Wait") as Button).pressed.emit()
		await _settle()
	_check(controller.phase == BattleController.Phase.ENEMY_TURN, "Enemy phase reached automatically from the initiative queue")
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	await create_timer(0.5).timeout
	_check(controller.state.turn_number == 0 and controller.state.get_actor(&"crew_1").health == 30, "Restart cancels the previous battle's pending enemy action")
	controller.enemy_timer.wait_time = 0.001
	for attempt: int in range(12):
		await _await_player(controller)
		if controller.state.enemy_ranks.size() < 4:
			break
		var command: ActionCommand = _first_attack(controller.state)
		current_scene.call("select_action", command.action_id)
		var enemy: ActorState = controller.state.get_actor(command.target_ids[0])
		_slot(enemy.side, controller.state.get_rank(enemy.id)).pressed.emit()
		await _settle()
	_check(controller.state.get_actor(&"enemy_1") == null and _slot(ActorState.Team.ENEMY, 1).text.contains("E2") and _slot(ActorState.Team.ENEMY, 4).text.contains("EMPTY"), "First enemy removal updates visible rank labels and empties the rear slot")
	await _check_outcome_layout("battle_compacted")
	await _play_to_outcome(controller, false)
	_check(controller.state.outcome == &"victory", "Four-position battle can be won through UI targets")
	_check((current_scene.get_node("%TurnLabel") as Label).text.contains("VICTORY") and (current_scene.get_node("%Wait") as Button).disabled, "Victory visible and input terminal")
	var terminal_turn: int = controller.state.turn_number
	(current_scene.get_node("%Wait") as Button).pressed.emit()
	_check(controller.state.turn_number == terminal_turn, "Post-victory input has no effect")
	await _check_outcome_layout("battle_victory")
	print("M3 VICTORY: round ", controller.state.round_number, " / turns ", controller.state.turn_number)
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	await _play_to_outcome(controller, true)
	_check(controller.state.outcome == &"defeat" and controller.state.crew_ranks.is_empty(), "Waiting can lose the full party battle")
	_check((current_scene.get_node("%TurnLabel") as Label).text.contains("DEFEAT") and (current_scene.get_node("%Move") as Button).disabled, "Defeat visible and input terminal")
	await _check_outcome_layout("battle_defeat")
	print("M3 DEFEAT: round ", controller.state.round_number, " / turns ", controller.state.turn_number)
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	_check(controller.state.actors.size() == 8 and controller.state.outcome == &"ongoing", "Restart restores all eight actors after defeat")
	for attempt: int in range(16):
		if controller.phase == BattleController.Phase.ENEMY_TURN:
			break
		controller.enemy_timer.wait_time = 0.4
		(current_scene.get_node("%Wait") as Button).pressed.emit()
		await _settle()
	(current_scene.get_node("%BackToHub") as Button).pressed.emit()
	await _settle()
	await create_timer(0.5).timeout
	_check(current_scene.scene_file_path == HUB, "Leaving during enemy response safely frees the battle")


func _slot(team: ActorState.Team, rank: int) -> Button:
	var prefix: String = "Crew" if team == ActorState.Team.CREW else "Enemy"
	return current_scene.get_node("%%%sRank%d" % [prefix, rank]) as Button


func _first_attack(state: CombatState) -> ActionCommand:
	for command: ActionCommand in CombatRules.get_legal_actions(state, state.active_actor_id):
		if command.action_id not in [&"move", &"wait"]:
			return command
	return null


func _await_player(controller: BattleController) -> void:
	for attempt: int in range(500):
		if controller.phase in [BattleController.Phase.PLAYER_INPUT, BattleController.Phase.FINISHED]:
			return
		await create_timer(0.01).timeout
	_check(false, "Enemy/resolution timeout")


func _play_to_outcome(controller: BattleController, waits: bool) -> void:
	for action: int in range(200):
		await _await_player(controller)
		if controller.state.outcome != &"ongoing":
			return
		if waits:
			(current_scene.get_node("%Wait") as Button).pressed.emit()
		else:
			var command: ActionCommand = _first_attack(controller.state)
			if command == null:
				(current_scene.get_node("%Wait") as Button).pressed.emit()
			else:
				current_scene.call("select_action", command.action_id)
				var target: ActorState = controller.state.get_actor(command.target_ids[0])
				_slot(target.side, controller.state.get_rank(target.id)).pressed.emit()
		await _settle()
	_check(false, "Battle did not reach a terminal outcome")


func _check_outcome_layout(artifact_name: String) -> void:
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		await _settle()
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, artifact_name)


func _open(scene_path: String) -> void:
	var result: Error = change_scene_to_file(scene_path)
	_check(result == OK, "Load %s" % scene_path)
	await _settle()


func _settle() -> void:
	for frame: int in range(4):
		await process_frame


func _press_key(keycode: Key, shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.shift_pressed = shift
	event.pressed = true
	Input.parse_input_event(event)
	await _settle()
	event = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.shift_pressed = shift
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _click_button(button: Button) -> void:
	var centre: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = centre
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = centre
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await _settle()


func _capture(scene_path: String, window_size: Vector2i, artifact_name: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "Screenshots require a graphical rendering run, not --headless")
		return
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var basename: String = scene_path.get_file().get_basename() if artifact_name.is_empty() else artifact_name
	var filename: String = "res://.artifacts/%s_%dx%d.png" % [basename, window_size.x, window_size.y]
	# Viewport images exclude the black bars added by the Window. At 1280x900
	# the 16:9 game content is still 1280x720, centred in the taller window.
	var fit: float = minf(window_size.x / 1920.0, window_size.y / 1080.0)
	var content_size: Vector2i = Vector2i(Vector2(1920, 1080) * fit)
	_check(root.size == window_size, "Window has requested dimensions: %s" % window_size)
	_check(screenshot.get_size() == content_size, "Rendered content is %s inside %s" % [content_size, window_size])
	_check(screenshot.save_png(filename) == OK, "Saved rendered screenshot: %s" % filename)


func _check_layout(scene_path: String, window_size: Vector2i) -> void:
	var viewport_rect: Rect2 = root.get_visible_rect().grow(1.0)
	var layout_ok: bool = true
	for node: Node in current_scene.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		if not viewport_rect.encloses(control.get_global_rect()):
			layout_ok = false
			printerr("Outside viewport: %s %s" % [control.get_path(), control.get_global_rect()])
		if control is Label or control is Button:
			var minimum: Vector2 = control.get_combined_minimum_size()
			if control.size.x + 1.0 < minimum.x or control.size.y + 1.0 < minimum.y:
				layout_ok = false
				printerr("Text below minimum size: %s" % control.get_path())
	_check(layout_ok, "Controls fit: %s at %s" % [scene_path, window_size])
	var focused: Control = root.gui_get_focus_owner()
	_check(focused is Button and current_scene.is_ancestor_of(focused), "Keyboard focus ready: %s" % scene_path)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		printerr("FAIL: ", description)
