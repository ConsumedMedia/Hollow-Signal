class_name CorridorView
extends Control
## Short native 2D presentation. Finishing or skipping calls the same arrival rule.
signal finished
var crew_count: int = 4
var progress: float = 0.0:
	set(value):
		progress = value
		queue_redraw()
var _tween: Tween
var _running: bool = false

func begin(seconds: float) -> void:
	if _running:
		return
	_running = true
	progress = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "progress", 1.0, seconds)
	_tween.finished.connect(finish)

func finish() -> void:
	if not _running:
		return
	_running = false
	if _tween != null:
		_tween.kill()
	progress = 1.0
	visible = false
	finished.emit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d29"))
	var floor_y: float = size.y * 0.8
	for column: int in range(-2, 14):
		var x: float = column * 180.0 - fmod(progress * 720.0, 180.0)
		draw_rect(Rect2(x + 12.0, 12.0, 155.0, floor_y - 20.0), Color("203343"))
		draw_line(Vector2(x + 20.0, 40.0), Vector2(x + 150.0, 40.0), Color("4d6674"), 4.0)
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), Color("070d14"))
	for member: int in range(crew_count):
		var x: float = size.x * 0.4 + member * 58.0
		var bounce: float = sin(progress * TAU * 5.0 + member) * 3.0
		draw_rect(Rect2(x, floor_y - 65.0 + bounce, 25.0, 42.0), Color("4d9296"))
		draw_rect(Rect2(x + 4.0, floor_y - 83.0 + bounce, 17.0, 17.0), Color("77d5d9"))
		draw_line(Vector2(x + 5.0, floor_y - 24.0), Vector2(x + 3.0 + bounce, floor_y), Color("4d9296"), 8.0)
		draw_line(Vector2(x + 20.0, floor_y - 24.0), Vector2(x + 23.0 - bounce, floor_y), Color("4d9296"), 8.0)
