class_name TileLayer
extends Node2D
## Draws the level's tiles in a single cached draw pass.
## Solid ground and platforms are drawn as black silhouettes; animated tiles
## (spikes) keep their colours so hazards stay readable.

const TEX := preload("res://assets/tilesets/tiles.png")
const SILHOUETTE := Color.BLACK

var _tiles: Array = []       # [src: Rect2, dst: Vector2]
var _anim_tiles: Array = []  # [src_a: Rect2, src_b: Rect2, dst: Vector2]
var _frame := 0


func add_tile(src: Rect2, dst: Vector2) -> void:
	_tiles.append([src, dst])


func add_anim_tile(src_a: Rect2, src_b: Rect2, dst: Vector2) -> void:
	_anim_tiles.append([src_a, src_b, dst])


func toggle_anim() -> void:
	if _anim_tiles.is_empty():
		return
	_frame ^= 1
	queue_redraw()


func _draw() -> void:
	for t in _tiles:
		draw_texture_rect_region(TEX, Rect2(t[1], Vector2(8, 8)), t[0], SILHOUETTE)
	for t in _anim_tiles:
		draw_texture_rect_region(TEX, Rect2(t[2], Vector2(8, 8)), t[_frame])
