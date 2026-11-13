extends Node
## Checks flyer rules on level 5 (Incoming).
## Run: godot --headless --path . --fixed-fps 60 res://tests/flyer_test.tscn
##   attempt 1: record flyer 0:0's position at tick 40, then rebound
##   attempt 2: same tick -> same position (the wave is identical); then stand
##              still until the low flyer hits -> death
##   attempt 3: drop onto flyer 0:0 -> stomp (bounce + pop), then rebound
##   attempt 4: the echo of attempt 3 pops flyer 0:0 on the same tick

const SAMPLE_TICK := 40
const STOMP_TICK := 40

var level: Level
var results: Array[String] = []
var ok := true
var frames := 0
var rebound := false
var sample := Vector2.ZERO
var stomp_at := -1


func _ready() -> void:
	Game.test_mode = true
	process_physics_priority = -100
	level = load("res://scenes/levels/level_5.tscn").instantiate()
	get_parent().add_child.call_deferred(level)


func _check(cond: bool, msg: String) -> void:
	results.append(("PASS " if cond else "FAIL ") + msg)
	ok = ok and cond


func _physics_process(_delta: float) -> void:
	frames += 1
	if level == null or not level.is_inside_tree() or level.player == null:
		return
	if frames > 60 * 60:
		_check(false, "timeout (attempt %d, tick %d)" % [level.attempt, level.tick])
		_finish()
		return
	rebound = false
	var playing := level.phase == Level.Phase.PLAYING
	match level.attempt:
		1:
			if playing and level.tick == SAMPLE_TICK:
				sample = level.flyers["0:0"].position
			elif playing and level.tick == SAMPLE_TICK + 20:
				rebound = true
		2:
			if playing and level.tick == SAMPLE_TICK:
				_check(level.flyers["0:0"].position == sample,
					"same wave every attempt (%s == %s)" % [level.flyers["0:0"].position, sample])
			if level.phase == Level.Phase.DYING and not has_meta("died"):
				set_meta("died", true)
				_check(level.tick > SAMPLE_TICK and level.player.state == Player.State.DEAD,
					"standing in the low lane gets you killed (tick %d)" % level.tick)
		3:
			if playing and level.tick == STOMP_TICK:
				var f: Flyer = level.flyers["0:0"]
				# ~10 ticks of falling; the flyer moves ~11 px left meanwhile
				level.player.position = Vector2(f.position.x - 10.0, f.hitbox().position.y - 12.0)
				level.player.velocity = Vector2.ZERO
			elif playing and stomp_at < 0 and level.tick > STOMP_TICK and level.flyers["0:0"].popped:
				stomp_at = level.tick
				_check(level.player.velocity.y < 0.0,
					"stomping bounces the player (vy=%.0f)" % level.player.velocity.y)
			elif playing and level.tick == STOMP_TICK + 40:
				_check(stomp_at > 0, "stomping pops the flyer (tick %d)" % stomp_at)
				rebound = true
		4:
			if playing and level.tick == stomp_at - 1:
				set_meta("before", level.flyers["0:0"].popped)
			elif playing and level.tick == stomp_at:
				_check(not get_meta("before", true) and level.flyers["0:0"].popped
					and level.player.position.x < 200.0,
					"the echo pops the flyer it stomped, on the same tick (%d)" % level.tick)
				_finish()
				return
	level.player.input_override = {
		"x": 0.0, "jump_pressed": false, "jump_held": false, "jump_released": false,
		"rebound": rebound,
	}


func _finish() -> void:
	for r in results:
		print(r)
	print("FLYER TEST PASSED" if ok and results.size() == 5 else "FLYER TEST FAILED")
	get_tree().quit(0 if ok and results.size() == 5 else 1)
