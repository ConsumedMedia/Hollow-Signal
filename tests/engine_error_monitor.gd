extends Logger
## Tests must fail on script errors, not just on failed assertions.

var _errors: int = 0
var _mutex: Mutex = Mutex.new()


func _log_error(_function: String, _file: String, _line: int, _code: String,
		_rationale: String, _editor_notify: bool, error_type: int,
		_script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != Logger.ERROR_TYPE_WARNING:
		_mutex.lock()
		_errors += 1
		_mutex.unlock()


func error_count() -> int:
	_mutex.lock()
	var result: int = _errors
	_mutex.unlock()
	return result
