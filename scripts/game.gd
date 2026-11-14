extends Node
## Global game state: input map, audio, level flow and scene transitions.
## Registered as the "Game" autoload.

const LEVELS := [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
	"res://scenes/levels/level_4.tscn",
	"res://scenes/levels/level_5.tscn",
	"res://scenes/levels/level_6.tscn",
	"res://scenes/levels/level_7.tscn",
]
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const END_SCREEN := "res://scenes/ui/end_screen.tscn"
## Meme sound slots -> number of clips (assets/audio/meme/<slot>_<i>.ogg,
## produced by tools/fetch_meme_sfx.py). Pools pick randomly, never twice in a row.
const SFX := {
	"jump": 1, "land": 1, "death": 6, "rebound": 1, "echo": 1,
	"plate_on": 1, "plate_off": 1, "door_open": 1, "door_close": 1,
	"bounce": 1, "complete": 2, "respawn": 1, "select": 1,
	"flyer_chatter": 7, "flyer_pop": 4, "flyer_kill": 5,
}
## Voice lines share one channel so they never talk over each other: a new
## line waits for the current one (at most one waits; extras are dropped).
const VOICE_SLOTS := ["death", "rebound", "echo", "complete", "plate_on", "plate_off", "door_open", "door_close", "flyer_kill"]
## Lines that always take the waiting spot (replacing whatever was queued).
const PRIORITY_LINES := ["flyer_kill"]

## Set by the automated test runner: disables scene transitions on completion.
var test_mode := false
var current_level := 0
var failures := 0

var _sfx := {}         # slot -> Array[AudioStream]
var _last_pick := {}   # slot -> index of the clip played last time
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _voice_line: AudioStreamPlayer
var _queued_line := []  # [slot, volume_db] waiting for the voice channel
var _music: AudioStreamPlayer
var _fade: ColorRect
var _transitioning := false
var _quitting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Quit through quit_game() so audio is released cleanly (no leak errors).
	get_tree().auto_accept_quit = false
	_setup_input()
	for slot in SFX:
		var clips: Array[AudioStream] = []
		for i in SFX[slot]:
			clips.append(load("res://assets/audio/meme/%s_%d.ogg" % [slot, i]))
		_sfx[slot] = clips
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_voice_line = AudioStreamPlayer.new()
	add_child(_voice_line)
	_voice_line.finished.connect(_play_queued_line)
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
	_queued_line = []
	for p in _voices + [_voice_line]:
		if p:
			p.stop()
			p.stream = null
	# players owned by scene nodes (e.g. flyer chatter)
	for p in get_tree().get_nodes_in_group("sfx_players"):
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
	if not _sfx.has(sfx_name) or _quitting:
		return
	if sfx_name in VOICE_SLOTS:
		if _voice_line.playing:
			if _queued_line.is_empty() or sfx_name in PRIORITY_LINES:
				_queued_line = [sfx_name, volume_db]
			return
		_play_line(sfx_name, volume_db)
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = _pick(sfx_name)
	p.volume_db = volume_db - 4.0
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## A clip from a slot's pool, for nodes that play sounds on their own player
## (e.g. flyers, whose chatter is positional).
func pick(slot: String) -> AudioStream:
	return _pick(slot) if _sfx.has(slot) else null


## Random clip from a slot's pool, avoiding an immediate repeat.
func _pick(slot: String) -> AudioStream:
	var clips: Array = _sfx[slot]
	var i := randi() % clips.size()
	if clips.size() > 1 and i == _last_pick.get(slot, -1):
		i = (i + 1 + randi() % (clips.size() - 1)) % clips.size()
	_last_pick[slot] = i
	return clips[i]


func _play_line(slot: String, volume_db: float) -> void:
	_voice_line.stream = _pick(slot)
	_voice_line.volume_db = volume_db - 2.0
	_voice_line.play()


func _play_queued_line() -> void:
	if _queued_line.is_empty() or _quitting:
		return
	var q := _queued_line
	_queued_line = []
	_play_line(q[0], q[1])


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
	go_to_level(0)


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
