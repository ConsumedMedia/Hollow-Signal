class_name CharacterPresentation
extends Node2D
## Reusable geometric actor puppet. It consumes presentation requests only.

signal pose_finished
signal sound_requested(cue: StringName)

const CREW: Color = Color("77d5d9")
const ENEMY: Color = Color("dc9069")
const POSES: Array[StringName] = [&"idle", &"walk", &"attack", &"support", &"hurt", &"downed", &"death"]
const ART_SCALE: float = 1.3
const ART_BOUNDS: Rect2 = Rect2(-44.0, -120.0, 88.0, 144.0)

var actor_id: StringName = &""
var actor_name: String = "ACTOR"
var enemy: bool = false
var active: bool = false
var pose: StringName = &"idle"
var _base_position: Vector2
var _rest_scale: Vector2 = Vector2.ONE
var _rest_modulate: Color = Color.WHITE
var _tween: Tween
var _generation: int = 0


func configure(id: StringName, label: String, is_enemy: bool) -> void:
	actor_id = id
	actor_name = label
	enemy = is_enemy
	queue_redraw()


func set_ground_position(value: Vector2) -> void:
	set_rest_transform(value)


func set_rest_transform(value: Vector2, resting_scale: Vector2 = Vector2.ONE, resting_modulate: Color = Color.WHITE) -> void:
	_base_position = value
	_rest_scale = resting_scale
	_rest_modulate = resting_modulate
	position = value
	scale = resting_scale
	modulate = resting_modulate


func play_pose(requested: StringName, seconds: float = 0.12) -> void:
	_generation += 1
	var generation: int = _generation
	if _tween != null:
		_tween.kill()
	if requested not in POSES:
		# Missing artwork/animation is deliberately a successful immediate fallback.
		pose = &"idle"
		position = _base_position
		rotation = 0.0
		scale = _rest_scale
		modulate = _rest_modulate
		queue_redraw()
		call_deferred("_emit_pose_finished")
		return
	pose = requested
	queue_redraw()
	sound_requested.emit(_sound_cue(requested))
	if seconds <= 0.0:
		_finish_pose.call_deferred(generation)
		return
	_tween = create_tween()
	match requested:
		&"walk":
			_tween.tween_property(self, "position:y", _base_position.y - 7.0, seconds * 0.45)
			_tween.tween_property(self, "position:y", _base_position.y, seconds * 0.55)
		&"attack":
			var direction: float = 1.0 if not enemy else -1.0
			_tween.tween_property(self, "position:x", _base_position.x - direction * 10.0, seconds * 0.32)
			_tween.tween_property(self, "position:x", _base_position.x + direction * 24.0, seconds * 0.24)
			_tween.tween_property(self, "position:x", _base_position.x, seconds * 0.44)
		&"support":
			_tween.tween_property(self, "scale", _rest_scale * 1.08, seconds * 0.5)
			_tween.tween_property(self, "scale", _rest_scale, seconds * 0.5)
		&"hurt":
			_tween.tween_property(self, "modulate", Color("ffd5a8"), seconds * 0.25)
			_tween.tween_property(self, "modulate", _rest_modulate, seconds * 0.75)
		&"downed":
			_tween.tween_property(self, "rotation", (-PI / 2.0) if not enemy else (PI / 2.0), seconds)
		&"death":
			_tween.parallel().tween_property(self, "rotation", (-PI / 2.0) if not enemy else (PI / 2.0), seconds)
			_tween.parallel().tween_property(self, "modulate:a", 0.18, seconds)
		_:
			_tween.tween_interval(seconds)
	_tween.finished.connect(_finish_pose.bind(generation), CONNECT_ONE_SHOT)


func skip_pose() -> void:
	_generation += 1
	if _tween != null:
		_tween.kill()
	_reset_transform()
	pose_finished.emit()


func settle(final_pose: StringName = &"idle") -> void:
	_generation += 1
	if _tween != null:
		_tween.kill()
	_reset_transform()
	pose = final_pose if final_pose in POSES else &"idle"
	if pose == &"downed" or pose == &"death":
		rotation = (-PI / 2.0) if not enemy else (PI / 2.0)
	if pose == &"death":
		modulate.a = 0.18
	queue_redraw()


func visual_rect_in_parent() -> Rect2:
	return Rect2(position + ART_BOUNDS.position * ART_SCALE, ART_BOUNDS.size * ART_SCALE)


func _finish_pose(generation: int) -> void:
	if generation != _generation:
		return
	if pose not in [&"downed", &"death"]:
		_reset_transform()
	pose_finished.emit()


func _emit_pose_finished() -> void:
	pose_finished.emit()


func _reset_transform() -> void:
	position = _base_position
	rotation = 0.0
	scale = _rest_scale
	modulate = _rest_modulate
	pose = &"idle"
	queue_redraw()


func _sound_cue(requested: StringName) -> StringName:
	match requested:
		&"attack": return &"attack"
		&"support": return &"support"
		&"hurt": return &"impact"
		&"downed": return &"downed"
		&"death": return &"death"
		_: return &""


func _draw() -> void:
	# Placeholder artwork is deliberately large enough to lead the scene rather
	# than reading as a small icon between interface rows.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ART_SCALE)
	var colour: Color = ENEMY if enemy else CREW
	# Ground shadow fixes every puppet to the shared action plane.
	_draw_shadow_ellipse(Vector2(0.0, 2.0), Vector2(42.0, 7.0), Color("03070b", 0.72))
	if active:
		draw_arc(Vector2(0.0, -42.0), 48.0, 0.0, TAU, 28, Color("ffd5a8"), 2.0)
	draw_rect(Rect2(-17.0, -38.0, 14.0, 38.0), colour.darkened(0.4))
	draw_rect(Rect2(3.0, -38.0, 14.0, 38.0), colour.darkened(0.4))
	draw_rect(Rect2(-26.0, -88.0, 52.0, 54.0), colour.darkened(0.18))
	draw_rect(Rect2(-34.0, -85.0, 10.0, 42.0), colour.darkened(0.35))
	draw_rect(Rect2(24.0, -85.0, 10.0, 42.0), colour.darkened(0.35))
	draw_rect(Rect2(-17.0, -118.0, 34.0, 28.0), colour)
	draw_rect(Rect2(-13.0, -111.0, 26.0, 9.0), Color("101d29"))
	draw_string(ThemeDB.fallback_font, Vector2(-42.0, 18.0), actor_name.left(12), HORIZONTAL_ALIGNMENT_CENTER, 84.0, 12, Color("dbe7ea"))


func _draw_shadow_ellipse(center: Vector2, radii: Vector2, colour: Color) -> void:
	var points: PackedVector2Array = []
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, colour)
