extends Control
## Shared screen navigation only. No campaign or combat state lives here.

@export var initial_focus: NodePath
@export_file("*.tscn") var back_scene: String = ""

var _transition_pending: bool = false


func _ready() -> void:
	get_window().min_size = Vector2i(960, 540)
	var first_button: Control = get_node_or_null(initial_focus) as Control
	if first_button != null:
		first_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		var window: Window = get_window()
		if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
			window.mode = Window.MODE_WINDOWED
		else:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not event.is_echo():
		if not back_scene.is_empty():
			open_screen(back_scene)
			get_viewport().set_input_as_handled()


func open_screen(scene_path: String) -> void:
	# Defer replacement until the button signal/input callback has finished.
	# The guard also rejects repeated requests in the same frame.
	if _transition_pending:
		return
	_transition_pending = true
	_change_screen.call_deferred(scene_path)


func _change_screen(scene_path: String) -> void:
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		_transition_pending = false
		push_error("Could not open %s: %s" % [scene_path, error_string(result)])


func quit_game() -> void:
	if not _transition_pending:
		get_tree().quit()
