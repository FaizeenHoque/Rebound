class_name LevelBackground
extends Node2D
## Layered parallax background. Levels use a city skyline (setup_city);
## the menus use the far grid (setup).

const FAR := preload("res://assets/sprites/bg_far.png")
const MID := preload("res://assets/sprites/bg_mid.png")
## CraftPix "free city backgrounds" pack: per city, its parallax layers from
## the sky (1.png) to the nearest buildings. The other files in each folder
## are pre-flattened composites and aren't used.
const CITY_DIR := "res://assets/sprites/free-city-backgrounds-pixel-art/city %d/%d.png"
const CITY_LAYERS := {
	1: [1, 2, 3, 4, 5], 2: [1, 2, 3, 4, 5, 6], 3: [1, 2, 3, 4, 5], 4: [1, 2, 3, 4, 5, 7],
	5: [1, 2, 3, 4, 5], 6: [1, 2, 3, 4, 5, 6], 7: [1, 2, 3, 4, 5], 8: [1, 2, 3, 4, 5],
}
const CITY_SIZE := Vector2(576, 324)
## Horizontal parallax of the sky and of the nearest buildings.
const SKY_SCROLL := 0.04
const NEAR_SCROLL := 0.5
## Dims the (bright, busy) skyline so the robot, flyers and hints stay readable.
const CITY_TINT := Color(0.45, 0.45, 0.55)

@export var autoscroll_speed := 0.0


static func has_city(city: int) -> bool:
	return CITY_LAYERS.has(city)


## City skyline at 1:1 pixel scale, its bottom on the level's bottom edge.
## Layers scroll horizontally at increasing speed and tile seamlessly.
func setup_city(city: int, level_size: Vector2) -> void:
	var layers: Array = CITY_LAYERS[city]
	modulate = CITY_TINT
	for i in layers.size():
		var par := Parallax2D.new()
		var t := float(i) / maxf(layers.size() - 1, 1.0)
		par.scroll_scale = Vector2(lerpf(SKY_SCROLL, NEAR_SCROLL, t), 1.0)
		par.repeat_size = Vector2(CITY_SIZE.x, 0)
		par.repeat_times = 3
		par.autoscroll = Vector2(-autoscroll_speed * t, 0)
		var spr := Sprite2D.new()
		spr.texture = load(CITY_DIR % [city, layers[i]])
		spr.centered = false
		spr.position = Vector2(0, level_size.y - CITY_SIZE.y)
		par.add_child(spr)
		add_child(par)

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
