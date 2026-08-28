extends SceneTree
## Load the rules suite AFTER installing the monitor, so compile errors fail too.

const ErrorMonitor = preload("res://tests/engine_error_monitor.gd")
var _monitor: ErrorMonitor = ErrorMonitor.new()


func _initialize() -> void:
	OS.add_logger(_monitor)
	_run.call_deferred()


func _run() -> void:
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
