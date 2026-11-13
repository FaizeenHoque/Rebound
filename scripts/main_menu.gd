extends Control
## Title screen with an animated robot and its echo walking behind it.

@onready var play_btn: Button = $Buttons/Play
@onready var title: Label = $Title
@onready var title_ghost: Label = $TitleGhost
@onready var robot: Sprite2D = $Robot
@onready var echo_sprite: Sprite2D = $EchoSprite

var _t := 0.0
var _glitch_t := 0.0
var _title_x := 0.0


func _ready() -> void:
	get_tree().paused = false
	_title_x = 160.0 - title.size.x * title.scale.x * 0.5
	title.position.x = _title_x
	$Background.setup(Vector2(320, 180))
	play_btn.pressed.connect(_on_play)
	$Buttons/Levels.pressed.connect(_on_levels)
	$Buttons/Quit.pressed.connect(_on_quit)
	play_btn.grab_focus()
	play_btn.focus_entered.connect(func() -> void: Game.sfx("select", -8.0))
	$Buttons/Levels.focus_entered.connect(func() -> void: Game.sfx("select", -8.0))
	$Buttons/Quit.focus_entered.connect(func() -> void: Game.sfx("select", -8.0))


func _process(delta: float) -> void:
	_t += delta
	var run_frame := 8 + int(_t * 12.0) % 6
	robot.frame = run_frame
	# the echo is the same run, a beat behind
	echo_sprite.frame = 8 + int((_t - 0.4) * 12.0) % 6
	_glitch_t -= delta
	if _glitch_t <= 0.0:
		_glitch_t = randf_range(0.08, 2.5)
		var on := randf() < 0.35
		title_ghost.visible = on
		title_ghost.position = Vector2(_title_x + randi_range(-3, 3), title.position.y + randi_range(-1, 1))
		title.position.x = _title_x + (randi_range(-1, 1) if on else 0)


func _on_play() -> void:
	Game.sfx("select")
	Game.start_game()


func _on_levels() -> void:
	Game.sfx("select")
	Game.to_level_select()


func _on_quit() -> void:
	Game.quit_game()
