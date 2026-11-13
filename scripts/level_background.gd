class_name LevelBackground
extends Node2D
## Layered parallax background: far grid, ruined server skyline, drifting motes.

const FAR := preload("res://assets/sprites/bg_far.png")
const MID := preload("res://assets/sprites/bg_mid.png")

@export var autoscroll_speed := 0.0

func setup(level_size: Vector2) -> void:
	var far := Parallax2D.new()
	far.scroll_scale = Vector2(0.15, 0.15)
	far.repeat_size = Vector2(64, 64)
	far.repeat_times = 3
	far.autoscroll = Vector2(-autoscroll_speed * 0.3, 0)
	var fs := Sprite2D.new()
	fs.texture = FAR
	fs.centered = false
	fs.region_enabled = true
	fs.region_rect = Rect2(0, 0, 448, 320)
	fs.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	fs.position = Vector2(-64, -64)
	far.add_child(fs)
	add_child(far)

	#var mid := Parallax2D.new()
	#mid.scroll_scale = Vector2(0.4, 0.4)
	#mid.repeat_size = Vector2(320, 0)
	#mid.repeat_times = 2
	#mid.autoscroll = Vector2(-autoscroll_speed, 0)
	#var ms := Sprite2D.new()
	#ms.texture = MID
	#ms.centered = false
	## anchor the skyline so its base sits near the bottom of the visible area
	#ms.position = Vector2(0, maxf(level_size.y * 0.4, 180.0) - MID.get_height() + 10)
	#ms.modulate = Color(1, 1, 1, 0.9)
	#mid.add_child(ms)
	#add_child(mid)

	#var motes := CPUParticles2D.new()
	#motes.amount = 40
	#motes.lifetime = 9.0
	#motes.preprocess = 9.0
	#motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	#motes.emission_rect_extents = level_size * 0.5 + Vector2(40, 40)
	#motes.position = level_size * 0.5
	#motes.direction = Vector2(0.3, -1)
	#motes.spread = 25.0
	#motes.gravity = Vector2.ZERO
	#motes.initial_velocity_min = 2.0
	#motes.initial_velocity_max = 7.0
	
	#var grad := Gradient.new()
	#grad.set_color(0, Color(0.133, 0.827, 0.933, 0.0))
	#grad.add_point(0.3, Color(0.133, 0.827, 0.933, 0.45))
	#grad.add_point(0.7, Color(0.655, 0.545, 0.98, 0.35))
	#grad.set_color(grad.get_point_count() - 1, Color(0.655, 0.545, 0.98, 0.0))
	#motes.color_ramp = grad
	#add_child(motes)
