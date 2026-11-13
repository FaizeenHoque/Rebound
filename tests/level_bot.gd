extends Node
## Automated playthrough of all levels using scripted input.
## Run: godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
## Each solution follows the intended route: record an attempt, rebound,
## then cooperate with the echo. Exits with code 0 only if every level is won.

const T := 8

# Commands: ["dir", d] ["jump", hold_ticks] ["x>=", px] ["x<=", px]
# ["wait", ticks] ["rebound"] ["playing"] ["open", door_idx] ["floor"]
var SOLUTIONS := {
	1: [
		["playing"], ["dir", 1],
		["x>=", 92], ["jump", 20],
		["x>=", 182], ["jump", 20],
		["x>=", 284], ["jump", 20],
		["x>=", 362], ["jump", 20], ["floor"],
		["x>=", 410], ["jump", 20], ["floor"],
		# walk off into the well: the spring at the bottom is the way up
	],
	2: [
		["playing"], ["dir", -1], ["x<=", 50], ["dir", 0],
		["wait", 240], ["rebound"],
		["playing"], ["dir", 1], ["x>=", 252], ["jump", 20],
	],
	3: [
		# attempt 1: bounce up, hold plate A, then hold plate B
		["playing"], ["dir", -1], ["x<=", 30], ["wait", 50], ["dir", 1],
		["x>=", 158], ["dir", 0], ["wait", 180],
		["dir", 1], ["x>=", 206], ["jump", 20],
		["x>=", 262], ["jump", 20], ["floor"],
		["x>=", 365], ["dir", 0], ["wait", 300], ["rebound"],
		# attempt 2: run the corridor behind the echo
		["playing"], ["dir", 1], ["x>=", 236], ["open", 0],
		["x>=", 280], ["jump", 20], ["floor"],
		["x>=", 328], ["jump", 20], ["floor"],
		["x>=", 392], ["open", 1],
	],
}

# Solo runs that must FAIL: proves doors block and the echo is required.
var NEGATIVE := {
	2: [["playing"], ["dir", 1], ["x>=", 252], ["jump", 20]],
	3: [
		["playing"], ["dir", -1], ["x<=", 30], ["wait", 50], ["dir", 1],
		["x>=", 158], ["dir", 0], ["wait", 180], ["rebound"],
		["playing"], ["dir", 1], ["x>=", 236], ["open", 0],
		["x>=", 280], ["jump", 20], ["floor"],
		["x>=", 328], ["jump", 20], ["floor"], ["x>=", 392],
	],
}
const NEGATIVE_LIMIT := 60 * 20

var negative_phase := false
var level: Level
var level_idx := 1
var cmds: Array = []
var pc := 0
var dir := 0.0
var jump_hold := 0
var jump_prev := false
var wait_left := 0
var ticks := 0
var results := []


func _ready() -> void:
	Game.test_mode = true
	process_physics_priority = -100
	_load_level(1)


func _load_level(n: int) -> void:
	if level:
		level.queue_free()
	level_idx = n
	level = load(Game.LEVELS[n - 1]).instantiate()
	get_parent().add_child.call_deferred(level)
	cmds = NEGATIVE[n] if negative_phase else SOLUTIONS[n]
	pc = 0
	dir = 0.0
	jump_hold = 0
	ticks = 0
	await get_tree().process_frame
	level.completed.connect(_on_completed)


func _on_completed() -> void:
	if negative_phase:
		results.append("NEGATIVE LEVEL %d: solved WITHOUT the intended echo use!" % level_idx)
		_finish(false)
		return
	results.append("LEVEL %d: COMPLETED in %d ticks, attempts=%d" % [level_idx, ticks, level.attempt])
	if level_idx < 3:
		_load_level(level_idx + 1)
	else:
		negative_phase = true
		_load_level(2)


func _finish(ok: bool) -> void:
	for r in results:
		print(r)
	print("ALL LEVELS COMPLETED" if ok else "TEST FAILED")
	get_tree().quit(0 if ok else 1)


var shot_dir := ""
const SHOTS := {1: [24], 2: [440]}


func _physics_process(_delta: float) -> void:
	if level == null or not level.is_inside_tree():
		return
	ticks += 1
	if shot_dir == "" and OS.get_cmdline_user_args().size() > 0:
		shot_dir = OS.get_cmdline_user_args()[0]
	if shot_dir != "" and not negative_phase and ticks in SHOTS.get(level_idx, []):
		get_viewport().get_texture().get_image().save_png("%s/l%d_%d.png" % [shot_dir, level_idx, ticks])
	if negative_phase and ticks > NEGATIVE_LIMIT:
		var door_x := level.doors[level.doors.size() - 1].position.x
		results.append("NEGATIVE LEVEL %d: blocked as expected (player x=%.0f, final door x=%.0f)" % [level_idx, level.player.position.x, door_x])
		if level.player.position.x >= door_x:
			_finish(false)
		elif level_idx == 2:
			_load_level(3)
		else:
			_finish(true)
		return
	if ticks > 60 * 60:
		results.append("LEVEL %d: TIMEOUT at cmd %d %s, player=%s attempt=%d" % [level_idx, pc, str(cmds[min(pc, cmds.size() - 1)]), str(level.player.position), level.attempt])
		_finish(false)
		return
	if level.player == null:
		return
	var p := level.player
	var rebound := false
	var jump_pressed := false
	# run commands until one blocks
	var guard := 0
	while pc < cmds.size() and guard < 20:
		guard += 1
		var c: Array = cmds[pc]
		var done := true
		match c[0]:
			"dir": dir = c[1]
			"jump":
				jump_pressed = true
				jump_hold = c[1]
			"x>=": done = p.position.x >= c[1]
			"x<=": done = p.position.x <= c[1]
			"wait":
				if wait_left == 0:
					wait_left = c[1]
				wait_left -= 1
				done = wait_left == 0
			"rebound": rebound = level.phase == Level.Phase.PLAYING
			"playing": done = level.phase == Level.Phase.PLAYING
			"floor": done = p.is_on_floor() and p.velocity.y >= 0
			"open": done = level.doors[c[1]].is_open
		if not done:
			break
		pc += 1
		if rebound or jump_pressed:
			break
	var held := jump_hold > 0
	if jump_hold > 0:
		jump_hold -= 1
	p.input_override = {
		"x": dir, "jump_pressed": jump_pressed, "jump_held": held or jump_pressed,
		"jump_released": jump_prev and not held and not jump_pressed, "rebound": rebound,
	}
	jump_prev = held or jump_pressed
	if level.phase == Level.Phase.DYING and not rebound and level._phase_t >= Level.DEATH_TIME - 0.01:
		results.append("  lvl %d death at %s (cmd %d)" % [level_idx, str(p.position), pc])
