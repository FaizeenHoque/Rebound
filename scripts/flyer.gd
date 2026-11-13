class_name Flyer
extends Node2D
## A flying enemy that crosses the level from right to left.
## Its position is a pure function of the level's attempt tick, so every
## attempt (and every echo replay) sees exactly the same wave.
## Sprite sheet: horizontal strip of 16x16 frames, facing left.

const FRAME := 16
const FRAME_TICKS := 8
## Hitbox relative to the centre.
const HITBOX := Rect2(-6, -5, 12, 10)

var spawn_tick := 0
var start := Vector2.ZERO
var speed := 40.0
var bob := 0.0
var popped := false

@onready var sprite: Sprite2D = $Sprite
@onready var burst: CPUParticles2D = $Burst


func _ready() -> void:
	if sprite.texture:
		sprite.hframes = maxi(1, sprite.texture.get_width() / FRAME)


func setup(p_spawn_tick: int, p_start: Vector2, p_speed: float, p_bob: float) -> void:
	spawn_tick = p_spawn_tick
	start = p_start
	speed = p_speed
	bob = p_bob


## Position at a given level tick.
func pos_at(tick: int) -> Vector2:
	var t := tick - spawn_tick
	return Vector2(start.x - speed * t / 60.0, start.y + bob * sin(t * 0.08))


func place(tick: int) -> void:
	position = pos_at(tick)
	if sprite.hframes > 1:
		sprite.frame = ((tick - spawn_tick) / FRAME_TICKS) % sprite.hframes


func hitbox() -> Rect2:
	return Rect2(position + HITBOX.position, HITBOX.size)


func pop() -> void:
	popped = true
	sprite.visible = false
	burst.restart()
	burst.emitting = true
	# The level frees it at the next attempt; it stays in the wave's
	# bookkeeping so it isn't respawned during this one.
