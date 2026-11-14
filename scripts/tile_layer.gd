class_name TileLayer
extends Node2D
## Draws the level's terrain in a single cached draw pass: black silhouette
## blocks with a bright rim on every exposed side, so the ground always reads
## against the city backdrop. Spikes are plain black triangles with a pink
## (danger) outline.

const TILE := 8
const SILHOUETTE := Color.BLACK
const RIM := Color("#a5f3fc")
const DANGER := Color("#f472b6")

var _solids: Array = []     # [at: Vector2, exposed-side mask: int]
var _platforms: Array = []  # [at: Vector2]
var _spikes: Array = []     # [at: Vector2, points_up: bool]


## The robot's look outside levels (menus): black silhouette, light outline.
static func silhouette_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/flash.gdshader")
	m.set_shader_parameter("base_tint", SILHOUETTE)
	m.set_shader_parameter("outline_color", RIM)
	m.set_shader_parameter("frame_size", Vector2(16, 16))
	return m


## mask bits: 1 = top exposed, 2 = right, 4 = bottom, 8 = left.
func add_solid(at: Vector2, mask: int) -> void:
	_solids.append([at, mask])


func add_platform(at: Vector2) -> void:
	_platforms.append([at])


func add_spike(at: Vector2, points_up: bool) -> void:
	_spikes.append([at, points_up])


func _draw() -> void:
	for s in _solids:
		var at: Vector2 = s[0]
		var mask: int = s[1]
		draw_rect(Rect2(at, Vector2(TILE, TILE)), SILHOUETTE)
		if mask & 1:
			draw_rect(Rect2(at, Vector2(TILE, 1)), RIM)
		if mask & 2:
			draw_rect(Rect2(at + Vector2(TILE - 1, 0), Vector2(1, TILE)), RIM)
		if mask & 4:
			draw_rect(Rect2(at + Vector2(0, TILE - 1), Vector2(TILE, 1)), RIM)
		if mask & 8:
			draw_rect(Rect2(at, Vector2(1, TILE)), RIM)
	for p in _platforms:
		var at: Vector2 = p[0]
		draw_rect(Rect2(at, Vector2(TILE, 3)), SILHOUETTE)
		draw_rect(Rect2(at, Vector2(TILE, 1)), RIM)
	for s in _spikes:
		var at: Vector2 = s[0]
		var pts: PackedVector2Array
		if s[1]:
			pts = PackedVector2Array([at + Vector2(0.5, 8), at + Vector2(4, 1), at + Vector2(7.5, 8)])
		else:
			pts = PackedVector2Array([at + Vector2(0.5, 0), at + Vector2(4, 7), at + Vector2(7.5, 0)])
		draw_colored_polygon(pts, SILHOUETTE)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), DANGER, 1.0)
