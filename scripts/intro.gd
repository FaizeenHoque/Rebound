extends Node2D
## Short, skippable opening: the robot runs, falls, glitches out... and
## bounces back while its failed run lingers as an echo. This time it jumps.

const ROBOT := preload("res://assets/sprites/robot.png")
const TILES := preload("res://assets/tilesets/tiles.png")
const ECHO_SHADER := preload("res://shaders/echo.gdshader")
const PAD_SCENE := preload("res://scenes/objects/bounce_pad.tscn")
const REBOUND_PAD_TEX := preload("res://assets/sprites/rebound_pad.png")

const FLOOR_Y := 136.0
const PIT_L := 176.0
const PIT_R := 208.0
const START_X := 48.0

var robot: Sprite2D
var echo: Sprite2D
var pad: BouncePad
var _anim := {}  # sprite -> "run" / "idle" / "fall"
var _t := 0.0
var _done := false

@onready var line1: Label = $UI/Line1
@onready var line2: Label = $UI/Line2
@onready var line3: Label = $UI/Line3
@onready var flash: ColorRect = $UI/Flash


func _ready() -> void:
	$Background.setup(Vector2(320, 180))
	_build_floor()
	pad = PAD_SCENE.instantiate()
	pad.position = Vector2(START_X - 8, FLOOR_Y)
	add_child(pad)
	pad.sprite.texture = REBOUND_PAD_TEX
	echo = _make_robot(true)
	echo.visible = false
	robot = _make_robot(false)
	for l in [line1, line2, line3]:
		l.visible_ratio = 0.0
	_play()


func _make_robot(is_echo: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = ROBOT
	s.hframes = 8
	s.vframes = 4
	s.offset = Vector2(0, -8)
	s.position = Vector2(START_X, FLOOR_Y)
	s.z_index = 4 if is_echo else 5
	if is_echo:
		var m := ShaderMaterial.new()
		m.shader = ECHO_SHADER
		s.material = m
	add_child(s)
	_anim[s] = "idle"
	return s


func _build_floor() -> void:
	var layer := TileLayer.new()
	add_child(layer)
	for x in 40:
		var px := x * 8.0
		if px >= PIT_L and px < PIT_R:
			continue
		var mask := 1
		if px + 8.0 == PIT_L:
			mask |= 2
		if px == PIT_R:
			mask |= 8
		for y in range(17, 23):
			var m := mask if y == 17 else (mask & 10)
			layer.add_tile(Rect2(m * 8, 0, 8, 8), Vector2(px, y * 8))
	layer.queue_redraw()


func _play() -> void:
	var tw := create_tween()
	tw.tween_property(line1, "visible_ratio", 1.0, 0.9)
	# attempt 1: run straight into the pit
	tw.tween_callback(func() -> void: _anim[robot] = "run")
	tw.tween_property(robot, "position:x", PIT_L + 10.0, 1.3)
	tw.tween_callback(func() -> void: _anim[robot] = "fall")
	tw.tween_property(robot, "position:y", FLOOR_Y + 30.0, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(_fail)
	tw.tween_property(line2, "visible_ratio", 1.0, 0.8)
	tw.tween_interval(0.3)
	# bounce back
	tw.tween_callback(_bounce_back)
	tw.tween_property(robot, "position:y", FLOOR_Y - 30.0, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(robot, "position:y", FLOOR_Y, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		Game.sfx("land", -8.0)
		_anim[robot] = "run"
		_anim[echo] = "run")
	# the echo repeats the failure; the robot uses it and jumps
	tw.tween_property(robot, "position:x", PIT_L - 14.0, 1.0)
	tw.parallel().tween_property(echo, "position:x", PIT_L - 14.0, 1.0)
	tw.tween_callback(func() -> void:
		_anim[robot] = "jump"
		Game.sfx("jump", -4.0))
	tw.tween_property(robot, "position:x", PIT_R + 26.0, 0.55)
	tw.parallel().tween_method(func(v: float) -> void: robot.position.y = FLOOR_Y - sin(v * PI) * 26.0, 0.0, 1.0, 0.55)
	tw.parallel().tween_property(echo, "position:x", PIT_L + 10.0, 0.3)
	tw.parallel().tween_property(line3, "visible_ratio", 1.0, 0.6)
	tw.tween_callback(func() -> void:
		_anim[robot] = "run"
		_anim[echo] = "fall"
		var fade := create_tween()
		fade.tween_property(echo, "position:y", FLOOR_Y + 30.0, 0.3)
		fade.parallel().tween_property(echo, "modulate:a", 0.0, 0.4))
	tw.tween_property(robot, "position:x", 340.0, 0.9)
	tw.tween_interval(0.6)
	tw.tween_callback(_finish)


func _fail() -> void:
	robot.visible = false
	Game.sfx("death")
	flash.color = Color("#f472b6")
	flash.modulate.a = 0.6
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.4)


func _bounce_back() -> void:
	robot.position = Vector2(START_X, FLOOR_Y)
	robot.visible = true
	_anim[robot] = "jump"
	echo.position = Vector2(START_X, FLOOR_Y)
	echo.visible = true
	pad.fire(true)
	Game.sfx("echo", -6.0)


func _process(delta: float) -> void:
	_t += delta
	for s in _anim:
		var sprite: Sprite2D = s
		match _anim[s]:
			"run": sprite.frame = 8 + int(_t * 12.0) % 6
			"jump": sprite.frame = 16
			"fall": sprite.frame = 18
			_: sprite.frame = [0, 1, 2, 1][int(_t * 5.0) % 4]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventJoypadButton):
		_finish()


func _finish() -> void:
	if _done or Game.is_transitioning():
		return
	_done = true
	Game.go_to_level(0)
