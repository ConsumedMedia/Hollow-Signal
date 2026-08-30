class_name CorridorView
extends Control
## Layered native 2D presentation. Finishing/skipping call the same arrival rule.
signal finished
const LAYER_SCRIPT: Script = preload("res://presentation/parallax_layer.gd")
var crew_count: int = 4
var progress: float = 0.0:
	set(value):
		progress = value
		_update_parallax()
		queue_redraw()
var _tween: Tween
var _running: bool = false
var _layers: Array[Parallax2D] = []


func _ready() -> void:
	# The corridor owns a clipped local canvas; this keeps its rear layers above
	# the expedition screen background and behind the crew silhouettes.
	z_index = 10
	resized.connect(_layout_layers)
	_build_layers()
	_layout_layers()

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
	var floor_y: float = size.y * 0.8
	for member: int in range(crew_count):
		var x: float = size.x * 0.4 + member * 58.0
		var bounce: float = sin(progress * TAU * 5.0 + member) * 3.0
		draw_rect(Rect2(x, floor_y - 65.0 + bounce, 25.0, 42.0), Color("4d9296"))
		draw_rect(Rect2(x + 4.0, floor_y - 83.0 + bounce, 17.0, 17.0), Color("77d5d9"))
		draw_line(Vector2(x + 5.0, floor_y - 24.0), Vector2(x + 3.0 + bounce, floor_y), Color("4d9296"), 8.0)
		draw_line(Vector2(x + 20.0, floor_y - 24.0), Vector2(x + 23.0 - bounce, floor_y), Color("4d9296"), 8.0)


func _build_layers() -> void:
	for kind: int in range(3):
		var parallax := Parallax2D.new()
		parallax.name = ["DistantParallax", "MachineryParallax", "ForegroundParallax"][kind]
		parallax.scroll_scale = [Vector2(0.15, 0.15), Vector2(0.4, 0.4), Vector2(1.15, 1.15)][kind]
		parallax.repeat_times = 3
		parallax.z_index = [-3, -2, 1][kind]
		var art := SignalParallaxLayer.new()
		art.name = "RepeatableArt"
		art.layer_kind = kind
		parallax.add_child(art)
		add_child(parallax)
		_layers.append(parallax)


func _layout_layers() -> void:
	for index: int in range(_layers.size()):
		var parallax: Parallax2D = _layers[index]
		parallax.repeat_size = Vector2(maxf(size.x, 1.0), 0.0)
		(parallax.get_node("RepeatableArt") as SignalParallaxLayer).configure(index, size)
	_update_parallax()


func _update_parallax() -> void:
	for index: int in range(_layers.size()):
		# The same travel progress drives presentation only; room arrival stays in
		# ExpeditionRules and the finished signal.
		_layers[index].scroll_offset.x = -progress * size.x * [0.15, 0.4, 1.15][index]
