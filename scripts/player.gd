class_name Player
extends CharacterBody2D

signal landed(impact: float)
signal jumped

const RUN_SPEED := 92.0
const ACCEL := 1000.0
const DECEL := 1400.0
const AIR_ACCEL := 800.0
const AIR_DECEL := 520.0
const JUMP_VELOCITY := -250.0
const GRAVITY_UP := 620.0
const GRAVITY_DOWN := 960.0
const MAX_FALL := 300.0
const JUMP_CUT := 0.5
const COYOTE_TICKS := 6
const BUFFER_TICKS := 7
const HEAVY_LANDING := 285.0  # a flat full jump lands at ~255
const BOUNCE_VELOCITY := -350.0

## Hitbox used for hazards / plates (relative to the feet origin).
const HITBOX := Rect2(-3, -11, 6, 10)

# frame indices in shadow.png (8 columns)
const ANIMS := {
	"idle": {"frames": [0, 1, 2, 1, 0, 3], "fps": 5.0},
	"run": {"frames": [8, 9, 10, 11, 12, 13], "fps": 12.0},
	"jump": {"frames": [16, 17], "fps": 10.0},
	"fall": {"frames": [18, 19], "fps": 8.0},
	"dead": {"frames": [24, 25, 26, 27, 28, 29], "fps": 14.0},
}

enum State { FROZEN, ACTIVE, DEAD }

var state := State.FROZEN
var facing := 1
## Optional scripted input (used by the automated level tests). Keys:
## x (float), jump_pressed, jump_held, jump_released (bool).
var input_override = null
var fx_parent: Node2D

var _coyote := 0
var _buffer := 0
var _bounced := false
var _was_on_floor := true
var _anim := "idle"
var _anim_time := 0.0
var _trail_tick := 0
var _flash := 0.0

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var dust: CPUParticles2D = $Dust


func _physics_process(delta: float) -> void:
	if state == State.ACTIVE:
		_move(delta)
	_animate(delta)
	visual.scale = visual.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	if _flash > 0.0:
		_flash = max(_flash - delta * 4.0, 0.0)
		(sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)


func _read_input() -> Dictionary:
	if input_override != null:
		return input_override
	return {
		"x": Input.get_axis("move_left", "move_right"),
		"jump_pressed": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"jump_released": Input.is_action_just_released("jump"),
	}


func _move(delta: float) -> void:
	var inp := _read_input()
	var dir: float = signf(inp.x) if absf(inp.x) > 0.2 else 0.0
	var on_floor := is_on_floor()

	var rate: float
	if dir != 0.0:
		rate = ACCEL if on_floor else AIR_ACCEL
		facing = int(dir)
	else:
		rate = DECEL if on_floor else AIR_DECEL
	velocity.x = move_toward(velocity.x, dir * RUN_SPEED, rate * delta)

	if on_floor:
		_coyote = COYOTE_TICKS
		if velocity.y >= 0.0:
			_bounced = false
	else:
		_coyote = max(_coyote - 1, 0)
	if inp.jump_pressed:
		_buffer = BUFFER_TICKS
	else:
		_buffer = max(_buffer - 1, 0)

	if _buffer > 0 and _coyote > 0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0
		_coyote = 0
		squash(Vector2(0.7, 1.35))
		Game.sfx("jump", -2.0)
		jumped.emit()

	if inp.jump_released and velocity.y < 0.0 and not _bounced:
		velocity.y *= JUMP_CUT

	var g := GRAVITY_UP if (velocity.y < 0.0 and (inp.jump_held or _bounced)) else GRAVITY_DOWN
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	var fall_speed := velocity.y
	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_on_land(fall_speed)
	_was_on_floor = is_on_floor()

	# afterimage trail when moving fast
	_trail_tick += 1
	if velocity.length() > 150.0 and _trail_tick % 3 == 0:
		_spawn_afterimage()


func _on_land(impact: float) -> void:
	var k := clampf(impact / MAX_FALL, 0.2, 1.0)
	squash(Vector2(1.0 + 0.45 * k, 1.0 - 0.4 * k))
	dust.amount = 6 + int(6 * k)
	dust.restart()
	dust.emitting = true
	# Vine boom, but only for genuinely big falls (it would get old fast).
	if impact > HEAVY_LANDING:
		Game.sfx("land", -4.0, 0.0)
	landed.emit(impact)


func squash(s: Vector2) -> void:
	visual.scale = s


func bounce(launch := BOUNCE_VELOCITY) -> void:
	velocity.y = launch
	_bounced = true
	_coyote = 0
	_buffer = 0
	squash(Vector2(0.55, 1.55))


func hitbox() -> Rect2:
	return Rect2(position + HITBOX.position, HITBOX.size)


## Encodes the visible sprite state for the echo recording.
func anim_code() -> int:
	return sprite.frame | ((1 if sprite.flip_h else 0) << 8)


func die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_set_anim("dead")
	_flash = 1.0
	squash(Vector2(1.4, 0.7))


func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	state = State.FROZEN
	facing = 1
	_was_on_floor = true
	_bounced = false
	_coyote = 0
	_buffer = 0
	_set_anim("idle")
	visual.scale = Vector2(0.1, 2.2)
	_flash = 1.0
	(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color("#22d3ee"))


func activate() -> void:
	state = State.ACTIVE
	(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color.WHITE)


func _set_anim(a: String) -> void:
	if _anim != a:
		_anim = a
		_anim_time = 0.0


func _animate(delta: float) -> void:
	if state != State.DEAD:
		if state == State.FROZEN or is_on_floor():
			_set_anim("run" if absf(velocity.x) > 12.0 else "idle")
		else:
			_set_anim("jump" if velocity.y < 0.0 else "fall")
	_anim_time += delta
	var data: Dictionary = ANIMS[_anim]
	var frames: Array = data.frames
	var idx := int(_anim_time * data.fps)
	if _anim == "dead":
		idx = mini(idx, frames.size() - 1)
		sprite.visible = _anim_time < 0.6
	else:
		idx %= frames.size()
		sprite.visible = true
	sprite.frame = frames[idx]
	sprite.flip_h = facing < 0


func _spawn_afterimage() -> void:
	if fx_parent == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.flip_h = sprite.flip_h
	ghost.position = position + sprite.position
	ghost.modulate = Color(0, 0, 0, 0.4)  # silhouette trail, like the robot
	fx_parent.add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)
