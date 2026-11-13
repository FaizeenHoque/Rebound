class_name PressurePlate
extends Node2D
## Pressed while the player or an active echo stands on it.
## Origin = bottom-left corner of the plate (on the floor surface).

const TEXTURES := [preload("res://assets/sprites/plate_a.png"), preload("res://assets/sprites/plate_b.png")]
const COLORS := [Color("#a78bfa"), Color("#60a5fa")]

var channel := 0
var pressed := false

@onready var sprite: Sprite2D = $Sprite
@onready var sparks: CPUParticles2D = $Sparks


func setup(p_channel: int) -> void:
	channel = p_channel


func _ready() -> void:
	sprite.texture = TEXTURES[channel]
	sparks.color = COLORS[channel]


## Feet must be in a thin band on top of the plate.
func trigger_rect() -> Rect2:
	return Rect2(position + Vector2(1, -5), Vector2(14, 7))


func is_pressed_by(hitbox: Rect2) -> bool:
	var feet := Rect2(hitbox.position.x, hitbox.end.y - 1, hitbox.size.x, 2)
	return trigger_rect().intersects(feet)


func set_pressed(p: bool) -> void:
	if p == pressed:
		return
	pressed = p
	sprite.frame = 1 if p else 0
	if p:
		sparks.restart()
		sparks.emitting = true
		Game.sfx("plate_on", -4.0)
	else:
		Game.sfx("plate_off", -8.0)
