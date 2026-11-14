extends Control
## Title screen: the silhouette robot and its echo run along a neon floor in
## front of a drifting city, while meme cats float past.

const FLYERS := 6

@onready var play_btn: Button = $Buttons/Play
@onready var title: Label = $Title
@onready var title_ghost: Label = $TitleGhost
@onready var robot: Sprite2D = $Robot
@onready var echo_sprite: Sprite2D = $EchoSprite

var _t := 0.0
var _glitch_t := 0.0
var _title_x := 0.0
var _flyers: Array[Sprite2D] = []
var _floor_memes: Array[Sprite2D] = []
var _chatter_t := 2.0


func _ready() -> void:
	get_tree().paused = false
	_title_x = 160.0 - title.size.x * title.scale.x * 0.5
	title.position.x = _title_x
	$Background.setup_city(8, Vector2(320, 180))
	$Floor.color = TileLayer.SILHOUETTE
	$FloorEdge.color = TileLayer.RIM
	robot.material = TileLayer.silhouette_material()
	_build_memes()
	play_btn.pressed.connect(_on_play)
	$Buttons/Quit.pressed.connect(_on_quit)
	# a browser tab can't be closed by the game, so there's nothing to quit to
	$Buttons/Quit.visible = not OS.has_feature("web")
	play_btn.grab_focus()
	play_btn.focus_entered.connect(func() -> void: Game.sfx("select", -8.0))
	$Buttons/Quit.focus_entered.connect(func() -> void: Game.sfx("select", -8.0))


func _build_memes() -> void:
	var sub := Label.new()
	sub.text = "NOW WITH 100% MORE CATS"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 75)
	sub.size = Vector2(320, 8)
	sub.modulate = Color("#fde047")
	add_child(sub)
	# meme cats drifting past behind the title
	for i in FLYERS:
		var f := Sprite2D.new()
		f.texture = Flyer.SKINS[i % Flyer.SKINS.size()]
		f.position = Vector2(40 + i * 60, 18 + (i * 37) % 44)
		add_child(f)
		move_child(f, $Background.get_index() + 1)
		_flyers.append(f)
	# two big memes vibing on the floor
	for i in 2:
		var m := Sprite2D.new()
		m.texture = Hud.MEMES[[2, 5][i]]
		m.scale = Vector2(0.5, 0.5)
		m.offset = Vector2(0, -32)
		m.position = Vector2([44, 276][i], 150)
		add_child(m)
		_floor_memes.append(m)


func _process(delta: float) -> void:
	_t += delta
	for i in _flyers.size():
		var f := _flyers[i]
		f.position.x -= (14.0 + i * 3.0) * delta
		if f.position.x < -12:
			f.position.x = 332
		f.position.y += sin(_t * 2.0 + i) * 0.15
	for i in _floor_memes.size():
		_floor_memes[i].position.y = 150 - absf(sin(_t * 4.0 + i * 1.7)) * 6.0
	_chatter_t -= delta
	if _chatter_t <= 0.0:
		_chatter_t = randf_range(2.5, 5.0)
		# the pop cat on the floor is pixel-cat-meme-3: it snores now and then
		Game.sfx("snore" if randf() < 0.3 else "flyer_chatter", -16.0, 0.3)
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


func _on_quit() -> void:
	Game.quit_game()
