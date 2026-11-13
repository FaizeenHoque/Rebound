extends Node
## Checks every meme SFX slot loads with sane clip lengths, and the voice-line
## queue: a second line waits, a third is dropped.
## Run: godot --headless --path . res://tests/sfx_test.tscn

const MAX_LEN := 3.0


func _ready() -> void:
	var ok := true
	for slot in Game.SFX:
		var clips: Array = Game._sfx.get(slot, [])
		if clips.size() != Game.SFX[slot]:
			print("FAIL %s: expected %d clips, got %d" % [slot, Game.SFX[slot], clips.size()])
			ok = false
			continue
		for i in clips.size():
			var c: AudioStream = clips[i]
			var len := c.get_length() if c else 0.0
			var good := c != null and len > 0.05 and len <= MAX_LEN
			print("%s %s_%d %.2fs" % ["ok  " if good else "FAIL", slot, i, len])
			ok = ok and good
	# voice channel queueing
	Game.sfx("death")
	Game.sfx("echo")
	Game.sfx("complete")
	var queued: Array = Game._queued_line
	var q_ok: bool = Game._voice_line.playing and queued.size() == 2 and queued[0] == "echo"
	print("%s voice queue: playing=%s queued=%s" % ["ok  " if q_ok else "FAIL", Game._voice_line.playing, queued])
	ok = ok and q_ok
	# pool never repeats back-to-back
	var last := -1
	var rep_ok := true
	for i in 50:
		Game._pick("death")
		var cur: int = Game._last_pick["death"]
		if cur == last:
			rep_ok = false
		last = cur
	print("%s death pool avoids repeats" % ("ok  " if rep_ok else "FAIL"))
	ok = ok and rep_ok
	print("SFX TEST PASSED" if ok else "SFX TEST FAILED")
	Game.quit_game()
