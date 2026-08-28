extends SceneTree
## Milestone 1 integration smoke check. No third-party test framework.

const MENU: String = "res://scenes/main_menu.tscn"
const HUB: String = "res://scenes/hub.tscn"
const BATTLE: String = "res://scenes/battle_test.tscn"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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

	# Optional negative self-test proves this runner exits unsuccessfully.
	if "--self-test-failure" in OS.get_cmdline_user_args():
		_check(false, "Intentional failure to verify exit code")
	print("SETUP SMOKE: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


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


func _capture(scene_path: String, window_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "Screenshots require a graphical rendering run, not --headless")
		return
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var filename: String = "res://.artifacts/%s_%dx%d.png" % [scene_path.get_file().get_basename(), window_size.x, window_size.y]
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
