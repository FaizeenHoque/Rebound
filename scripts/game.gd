extends Node
## Global game state: input map, audio, level flow and scene transitions.
## Registered as the "Game" autoload.

const LEVELS := [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
]
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const END_SCREEN := "res://scenes/ui/end_screen.tscn"
const INTRO := "res://scenes/ui/intro.tscn"
const SFX_NAMES := [
	"jump", "land", "death", "echo", "plate_on", "plate_off",
	"door", "bounce", "complete", "respawn", "select",
]

## Set by the automated test runner: disables scene transitions on completion.
var test_mode := false
var current_level := 0
var failures := 0

var _sfx := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _fade: ColorRect
var _transitioning := false
var _quitting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Quit through quit_game() so audio is released cleanly (no leak errors).
	get_tree().auto_accept_quit = false
	_setup_input()
	for sfx_name in SFX_NAMES:
		_sfx[sfx_name] = load("res://assets/audio/%s.wav" % sfx_name)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_setup_music()
	_setup_fade()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Stops all audio, lets the audio thread release its playbacks, then quits.
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	_release_audio()
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()


func _exit_tree() -> void:
	_release_audio()


func _release_audio() -> void:
	if _music:
		_music.stop()
		_music.stream = null
	for p in _voices:
		p.stop()
		p.stream = null


# ------------------------------------------------------------------ input

func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_bind("jump", [KEY_SPACE, KEY_W, KEY_UP, KEY_Z], [JOY_BUTTON_A])
	_bind("rebound", [KEY_R], [JOY_BUTTON_Y])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	var axis_l := InputEventJoypadMotion.new()
	axis_l.axis = JOY_AXIS_LEFT_X
	axis_l.axis_value = -1.0
	InputMap.action_add_event("move_left", axis_l)
	var axis_r := InputEventJoypadMotion.new()
	axis_r.axis = JOY_AXIS_LEFT_X
	axis_r.axis_value = 1.0
	InputMap.action_add_event("move_right", axis_r)


func _bind(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)


# ------------------------------------------------------------------ audio

func sfx(sfx_name: String, volume_db := 0.0, pitch_jitter := 0.05) -> void:
	if not _sfx.has(sfx_name):
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = _sfx[sfx_name]
	p.volume_db = volume_db - 4.0
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _setup_music() -> void:
	# Looping is configured in ambient.wav.import (edit/loop_mode = Forward).
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/audio/ambient.wav")
	_music.volume_db = -16.0
	add_child(_music)
	_music.play()


# ------------------------------------------------------------------ flow

func start_game() -> void:
	failures = 0
	current_level = 0
	change_scene(INTRO)


func go_to_level(index: int) -> void:
	current_level = index
	change_scene(LEVELS[index])


func restart_level() -> void:
	change_scene(LEVELS[current_level])


func to_main_menu() -> void:
	change_scene(MAIN_MENU)


func level_completed() -> void:
	if test_mode:
		return
	if current_level + 1 < LEVELS.size():
		go_to_level(current_level + 1)
	else:
		change_scene(END_SCREEN)


func is_transitioning() -> bool:
	return _transitioning


func change_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	var mat: ShaderMaterial = _fade.material
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.35)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 1.0, 0.0, 0.35)
	await tw2.finished
	_transitioning = false


func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/transition.gdshader")
	mat.set_shader_parameter("progress", 0.0)
	_fade.material = mat
	layer.add_child(_fade)
