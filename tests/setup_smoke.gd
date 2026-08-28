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
	var attack: Button = current_scene.get_node("%Attack") as Button
	var wait: Button = current_scene.get_node("%Wait") as Button
	_check(controller.state.actors[0].health == 30 and controller.state.actors[1].health == 20, "Battle starts with independent full-health actors")
	_check(not attack.disabled and not wait.disabled and root.gui_get_focus_owner() == attack, "Player actions begin enabled and focused")
	var initial_rng: int = controller.rng.state
	attack.pressed.emit()
	var first_damage: int = 20 - controller.state.actors[1].health
	attack.pressed.emit()
	wait.pressed.emit()
	_check(controller.state.turn_number == 1 and controller.phase == BattleController.Phase.ENEMY_TURN, "Repeated player input resolves only one action")
	_check(attack.disabled and wait.disabled, "Player buttons disabled during enemy response")
	_check(first_damage >= 6 and first_damage <= 8, "First attack displays the authored damage range")
	_check((current_scene.get_node("%Status") as Label).text.contains("%d damage" % first_damage), "Damage event appears in the combat log")
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	_check(controller.state.turn_number == 0 and controller.rng.state == initial_rng, "Restart resets state and seed during an enemy response")
	await create_timer(0.5).timeout
	_check(controller.state.actors[0].health == 30 and controller.state.turn_number == 0, "Restart cancels the previous battle's queued enemy action")
	controller.enemy_timer.wait_time = 0.01
	attack.pressed.emit()
	_check(20 - controller.state.actors[1].health == first_damage, "Restart repeats the same first damage roll")
	await _await_enemy(controller)
	_check(controller.state.turn_number == 2 and controller.state.actors[0].health < 30, "Enemy responds once and returns the player's turn")
	for turn: int in range(10):
		if controller.state.outcome != &"ongoing":
			break
		attack.pressed.emit()
		await _await_enemy(controller)
	_check(controller.state.outcome == &"victory", "Player can win a complete battle through the UI")
	_check(attack.disabled and wait.disabled and (current_scene.get_node("%TurnLabel") as Label).text.contains("VICTORY"), "Victory is visible and combat input is disabled")
	var final_turn: int = controller.state.turn_number
	var final_rng: int = controller.rng.state
	attack.pressed.emit()
	wait.pressed.emit()
	_check(controller.state.turn_number == final_turn and controller.rng.state == final_rng, "Post-victory input cannot change state or RNG")
	await _check_outcome_layout("battle_victory")
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	for turn: int in range(12):
		if controller.state.outcome != &"ongoing":
			break
		wait.pressed.emit()
		await _await_enemy(controller)
	_check(controller.state.outcome == &"defeat" and controller.state.actors[1].health == 20, "Waiting can lose a complete battle without damaging the enemy")
	_check(attack.disabled and wait.disabled and (current_scene.get_node("%TurnLabel") as Label).text.contains("DEFEAT"), "Defeat is visible and combat input is disabled")
	await _check_outcome_layout("battle_defeat")
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	_check(controller.state.outcome == &"ongoing" and controller.state.actors[0].health == 30, "Restart works after defeat")
	attack.pressed.emit()
	(current_scene.get_node("%BackToHub") as Button).pressed.emit()
	await _settle()
	await create_timer(0.1).timeout
	_check(current_scene.scene_file_path == HUB, "Leaving during enemy response safely frees the battle")


func _await_enemy(controller: BattleController) -> void:
	for attempt: int in range(200):
		if controller.phase != BattleController.Phase.ENEMY_TURN:
			return
		await create_timer(0.01).timeout
	_check(false, "Enemy turn timeout")


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
