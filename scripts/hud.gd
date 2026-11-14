class_name Hud
extends CanvasLayer
## In-game HUD: level, attempt counter, echo status + timeline, toasts, title card,
## and a meme that slams onto the screen whenever you die.

const MEMES: Array[Texture2D] = [
	preload("res://assets/sprites/memes_big/pixel-cat-meme-1.png"),
	preload("res://assets/sprites/memes_big/pixel-cat-meme-2.png"),
	preload("res://assets/sprites/memes_big/pixel-cat-meme-3.png"),
	preload("res://assets/sprites/memes_big/pixel-cat-meme-4.png"),
	preload("res://assets/sprites/memes_big/pixel-cat-meme-5.png"),
	preload("res://assets/sprites/memes_big/pixel-shiba-dog.png"),
]

@onready var level_label: Label = $Top/Level
@onready var attempt_label: Label = $Top/Attempt
@onready var echo_label: Label = $Top/Echo
@onready var echo_bar: ColorRect = $Top/EchoBar/Fill
@onready var toast_label: Label = $Toast
@onready var title_card: Control = $TitleCard
@onready var title_num: Label = $TitleCard/Num
@onready var title_name: Label = $TitleCard/Name

@onready var fail_big: Label = $Fail/Big
@onready var fail_ghost: Label = $Fail/Ghost
@onready var fail_sub: Label = $Fail/Sub
@onready var fail_root: Control = $Fail

var _toast_tween: Tween
var _fail_tween: Tween
var _meme: Sprite2D
var _meme_tween: Tween
var _last_meme := -1


func show_title(num: int, title: String) -> void:
	level_label.text = "LV%d %s" % [num, title]
	title_num.text = "- LEVEL %d -" % num
	title_name.text = title
	title_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(title_card, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.6)
	tw.tween_property(title_card, "modulate:a", 0.0, 0.6)


func set_stats(attempt: int, echo_status: String, echo_color: Color, progress: float) -> void:
	attempt_label.text = "ATTEMPT %d" % attempt
	echo_label.text = "ECHO: " + echo_status
	echo_label.modulate = echo_color
	echo_bar.size.x = roundf(60.0 * progress)
	echo_bar.color = echo_color


func toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _ready() -> void:
	_meme = Sprite2D.new()
	_meme.position = Vector2(160, 116)
	_meme.visible = false
	add_child(_meme)


## A random meme (never the same twice in a row) slams in, then fades out.
func meme_popup() -> void:
	var i := randi() % MEMES.size()
	if i == _last_meme:
		i = (i + 1) % MEMES.size()
	_last_meme = i
	_meme.texture = MEMES[i]
	_meme.visible = true
	_meme.modulate.a = 1.0
	_meme.scale = Vector2(2.2, 2.2)
	_meme.rotation = randf_range(-0.35, 0.35)
	if _meme_tween:
		_meme_tween.kill()
	_meme_tween = create_tween()
	_meme_tween.tween_property(_meme, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_meme_tween.tween_interval(0.5)
	_meme_tween.tween_property(_meme, "modulate:a", 0.0, 0.25)
	_meme_tween.tween_callback(func() -> void: _meme.visible = false)


## Big glitchy message shown while the robot is failing.
func fail_message(headline: String, sub: String) -> void:
	fail_big.text = headline
	fail_ghost.text = headline
	fail_sub.text = sub
	var w := fail_big.get_theme_font("font").get_string_size(headline, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x * 2.0
	fail_big.position.x = roundf(160.0 - w * 0.5)
	fail_ghost.position = fail_big.position + Vector2(2, 1)
	if _fail_tween:
		_fail_tween.kill()
	fail_root.modulate.a = 1.0
	fail_root.scale = Vector2(1, 1)
	fail_ghost.visible = true
	_fail_tween = create_tween()
	_fail_tween.tween_interval(0.12)
	_fail_tween.tween_callback(func() -> void: fail_ghost.visible = false)
	_fail_tween.tween_interval(0.75)
	_fail_tween.tween_property(fail_root, "modulate:a", 0.0, 0.35)
