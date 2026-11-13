class_name Echo
extends Node2D
## Replays a recorded attempt, one recorded frame per physics tick.
## Purely visual + logical: no physics body, so it never blocks the player.
## The level drives playback through `apply_tick()` so the echo stays in
## lockstep with the tick counter that recorded it.

signal finished

var positions := PackedVector2Array()
var codes := PackedInt32Array()
## True while the echo is replaying and can press plates.
var active := false
var _fading := false

@onready var sprite: Sprite2D = $Sprite
@onready var motes: CPUParticles2D = $Motes
@onready var burst: CPUParticles2D = $Burst


func _ready() -> void:
	visible = false


## Labels the echo with the failed attempt it came from.
func set_tag(text: String) -> void:
	$Tag.text = text


func has_recording() -> bool:
	return positions.size() > 0


func length_ticks() -> int:
	return positions.size()


## Stores a new attempt, replacing any previous one.
func load_recording(p: PackedVector2Array, c: PackedInt32Array) -> void:
	positions = p.duplicate()
	codes = c.duplicate()


func clear() -> void:
	positions.clear()
	codes.clear()
	active = false
	visible = false


## Rewinds to frame 0 at the start of a new attempt.
func rewind(play_spawn_fx: bool) -> void:
	_fading = false
	if not has_recording():
		active = false
		visible = false
		return
	active = true
	visible = true
	modulate = Color.WHITE
	motes.emitting = true
	_show(0)
	_set_glitch(0.0)
	if play_spawn_fx:
		burst.restart()
		burst.emitting = true
		_set_glitch(1.0)
		var tw := create_tween()
		tw.tween_method(_set_glitch, 1.0, 0.0, 0.5)


func apply_tick(tick: int) -> void:
	if not active:
		return
	if tick >= positions.size():
		_finish()
		return
	_show(tick)


## Feet-based hitbox matching Player.HITBOX.
func hitbox() -> Rect2:
	return Rect2(position + Player.HITBOX.position, Player.HITBOX.size)


func progress(tick: int) -> float:
	if positions.is_empty():
		return 0.0
	return clampf(float(tick) / positions.size(), 0.0, 1.0)


func _show(i: int) -> void:
	position = positions[i]
	var code := codes[i]
	sprite.frame = code & 0xFF
	sprite.flip_h = (code >> 8) & 1 == 1


func _finish() -> void:
	active = false
	if _fading:
		return
	_fading = true
	motes.emitting = false
	burst.restart()
	burst.emitting = true
	var tw := create_tween()
	tw.tween_method(_set_glitch, 0.0, 1.0, 0.25)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void: visible = false)
	finished.emit()


func _set_glitch(v: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("glitch", v)
