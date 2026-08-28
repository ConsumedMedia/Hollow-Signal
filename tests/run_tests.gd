extends SceneTree
## Load the rules suite AFTER installing the monitor, so compile errors fail too.

const ErrorMonitor = preload("res://tests/engine_error_monitor.gd")
var _monitor: ErrorMonitor = ErrorMonitor.new()


func _initialize() -> void:
	OS.add_logger(_monitor)
	_run.call_deferred()


func _run() -> void:
	if not _check_room_resource_order():
		quit(1)
		return
	var suite_script: GDScript = load("res://tests/combat_rules_test.gd") as GDScript
	if suite_script == null or not suite_script.can_instantiate() or _monitor.error_count() > 0:
		printerr("RULES RUNNER: suite could not compile.")
		quit(1)
		return
	var suite: RefCounted = suite_script.new() as RefCounted
	# Dynamic loading is deliberate here: preloading would compile game code
	# before the error monitor is registered.
	var result: Variant = suite.call("run")
	if "--self-test-script-error" in OS.get_cmdline_user_args():
		var broken: GDScript = GDScript.new()
		broken.source_code = "extends RefCounted\nfunc broken(:\n"
		broken.reload()
	var failed: bool = typeof(result) != TYPE_INT or result != 0 or _monitor.error_count() > 0
	print("RULES RUNNER: engine errors = %d; exit = %d" % [_monitor.error_count(), 1 if failed else 0])
	quit(1 if failed else 0)


func _check_room_resource_order() -> bool:
	# Check text BEFORE loading the catalogue: bad dependencies prevent suite compilation.
	if _external_resources_first("[sub_resource type=\"Resource\" id=\"drop\"]\n[ext_resource type=\"Script\" id=\"late\"]"):
		printerr("RESOURCE ORDER: regression guard failed to reject a late external declaration.")
		return false
	var rooms: PackedStringArray = ["airlock", "receiving", "junction", "salvage", "hazard", "safe_room", "containment", "signal_core"]
	for room: String in rooms:
		var path: String = "res://content/rooms/%s.tres" % room
		var source: String = FileAccess.get_file_as_string(path)
		if source.is_empty() or not _external_resources_first(source):
			printerr("RESOURCE ORDER: external declarations must precede sub/main resources: ", path)
			return false
	print("RESOURCE ORDER: 8 room files passed; late-declaration regression rejected.")
	return true


func _external_resources_first(source: String) -> bool:
	var reached_resource: bool = false
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("[sub_resource ") or line == "[resource]":
			reached_resource = true
		elif reached_resource and line.begins_with("[ext_resource "):
			return false
	return true
