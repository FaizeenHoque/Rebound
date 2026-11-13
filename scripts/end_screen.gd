extends Control
## Ending: every failure from the run lines up behind the robot as an echo,
## then the closing lines land. Short and skippable to the menu button.

const ROBOT := preload("res://assets/sprites/robot.png")
const ECHO_SHADER := preload("res://shaders/echo.gdshader")
const MAX_ECHOES := 14
const FLOOR_Y := 132.0

var _echoes: Array[Sprite2D] = []
var _robot: Sprite2D
var _t := 0.0

@onready var line1: Label = $Line1
@onready var line2: Label = $Line2
@onready var stats: Label = $Stats
@onready var hearts: CPUParticles2D = $Hearts
@onready var menu_btn: Button = $Menu


func _ready() -> void:
	$Background.setup(Vector2(320, 180))
	var falls := Game.failures
	stats.text = "FALLS: %d     TIMES YOU BOUNCED BACK: %d" % [falls, falls]
	for l in [line1, line2]:
		l.visible_ratio = 0.0
	stats.modulate.a = 0.0
	menu_btn.modulate.a = 0.0
	menu_btn.pressed.connect(func() -> void:
		Game.sfx("select")
		Game.to_main_menu())

	_robot = _make_robot(false)
	_robot.position = Vector2(250, FLOOR_Y)
	var shown := mini(falls, MAX_ECHOES)
	for i in shown:
		var e := _make_robot(true)
		e.position = Vector2(232 - i * 14, FLOOR_Y)
		e.visible = false
		_echoes.append(e)

	var tw := create_tween()
	tw.tween_interval(0.5)
	for i in shown:
		tw.tween_callback(func() -> void:
			_echoes[i].visible = true
			Game.sfx("select", -10.0 + i * 0.3, 0.0))
		tw.tween_interval(0.12)
	tw.tween_interval(0.3)
	tw.tween_property(line1, "visible_ratio", 1.0, 1.0)
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		Game.sfx("complete")
		hearts.emitting = true
		_robot.frame = 16)
	tw.tween_property(line2, "visible_ratio", 1.0, 1.0)
	tw.tween_property(stats, "modulate:a", 1.0, 0.4)
	tw.tween_property(menu_btn, "modulate:a", 1.0, 0.3)
	tw.tween_callback(menu_btn.grab_focus)
	menu_btn.grab_focus()


func _make_robot(is_echo: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = ROBOT
	s.hframes = 8
	s.vframes = 4
	s.offset = Vector2(0, -8)
	if is_echo:
		var m := ShaderMaterial.new()
		m.shader = ECHO_SHADER
		m.set_shader_parameter("alpha", 0.6)
		s.material = m
	add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	# the echoes idle in a gentle wave; the robot hops for joy once freed
	for i in _echoes.size():
		_echoes[i].frame = [0, 1, 2, 1][int(_t * 5.0 + i) % 4]
	_robot.frame = [0, 1, 2, 1][int(_t * 5.0) % 4]	
