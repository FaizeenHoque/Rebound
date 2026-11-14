class_name Level
extends Node2D
## Builds a level from an ASCII map and runs the attempt / echo loop.
##
## Map legend:
##   #  solid block          -  one-way platform
##   ^  floor spikes         v  ceiling spikes
##   P  player start         E  exit portal (stands on the floor below)
##   o  bounce pad (2 wide)  a/b  pressure plate, channel A/B (2 wide)
##   A/B  door top, channel A/B (extends down to the next solid tile)
##
## Determinism: this node runs its physics step AFTER the player
## (process_physics_priority), so on every tick it records the player's
## final position, applies the echo frame with the same index and then
## evaluates plates, doors and hazards. The echo therefore presses plates on
## exactly the tick its original attempt did.

signal completed

const TILE := 8
const TILES_TEX := preload("res://assets/tilesets/tiles.png")
const DECOR_TEX := preload("res://assets/sprites/decor.png")
const PLATE_SCENE := preload("res://scenes/objects/pressure_plate.tscn")
const DOOR_SCENE := preload("res://scenes/objects/door.tscn")
const PAD_SCENE := preload("res://scenes/objects/bounce_pad.tscn")
const REBOUND_PAD_TEX := preload("res://assets/sprites/rebound_pad.png")
const EXIT_SCENE := preload("res://scenes/objects/exit_portal.tscn")
const TREES_TEX := preload("res://assets/sprites/decor_trees.png")
const FAIL_MARK_TEX := preload("res://assets/sprites/fx_fail_mark.png")
const STAR_TEX := preload("res://assets/sprites/fx_star.png")
const DOTS_TEX := preload("res://assets/sprites/fx_dots.png")
const FLYER_SCENE := preload("res://scenes/objects/flyer.tscn")

## Shown while the robot glitches out. [headline, subline]
const FAIL_LINES := [
	["SKILL ISSUE", "EVERY FALL LEAVES SOMETHING BEHIND"],
	["BRUH MOMENT", "THIS ATTEMPT BECOMES YOUR ECHO"],
	["EMOTIONAL DAMAGE", "YOUR FAILURE STAYS IN THE WORLD"],
	["IT'S JOEVER", "...OR IS IT? BOUNCE BACK"],
	["L + RATIO", "THE WORLD RESETS. YOUR FAILURE REMAINS"],
	["NOT LIKE THIS", "YOUR ECHO WILL REMEMBER THIS"],
	["MISSION FAILED", "WE'LL GET 'EM NEXT TIME"],
	["CERTIFIED OOF", "FAIL FORWARD"],
	["YOU DIED (LOL)", "BUT YOUR FAILURE LIVES ON"],
	["GIT GUD", "OR JUST FAIL SMARTER"],
]
const REBOUND_LINE := ["YEET", "FAILING ON PURPOSE IS A STRATEGY"]

const DEATH_TIME := 0.6
const RESPAWN_TIME := 0.75
const MIN_ECHO_TICKS := 15
const MAX_RECORD_TICKS := 60 * 90
const STOMP_VELOCITY := -260.0
## How far (px) above a flyer's top the feet may have been last tick to count as a stomp.
const STOMP_SLACK := 2.0

enum Phase { RESPAWNING, PLAYING, DYING, COMPLETE }

@export var level_number := 1
@export var level_title := "FIRST FALL"
@export_multiline var map := ""
## Floating hint text: "col,row|TEXT"
@export var hints := PackedStringArray()
## Flying enemy waves: "row|first_tick|interval|speed|bob". They enter from
## the right edge of the level and fly left, locked to the attempt tick.
@export var waves := PackedStringArray()

var phase := Phase.RESPAWNING
var attempt := 0
var tick := 0
var grid: Array[String] = []
var map_w := 0
var map_h := 0
var start_pos := Vector2.ZERO

var plates: Array[PressurePlate] = []
var doors: Array[Door] = []
var pads: Array[BouncePad] = []
var exit_portal: ExitPortal
var spike_rects: Array[Rect2] = []
## Live flyers, keyed "wave:index".
var flyers := {}

var _rec_pos := PackedVector2Array()
var _rec_code := PackedInt32Array()
var _phase_t := 0.0
var _echo_on_pad := false
var _decor: Array[Sprite2D] = []
var _decor_t := 0.0
var _complete_sent := false
var _new_echo := false
var _echo_attempt := 0
var _echo_helped := false
var _respawn_pad: BouncePad
var _death_spot := Vector2.ZERO
var _waves: Array[Dictionary] = []

@onready var terrain: TileLayer = $Terrain
@onready var solids: StaticBody2D = $Solids
@onready var objects: Node2D = $Objects
@onready var echo: Echo = $Echo
@onready var player: Player = $Player
@onready var fx: Node2D = _ensure_node("FX", Node2D, 6)
@onready var camera: CameraRig = $Camera
@onready var hud: Hud = $HUD
@onready var screen_fx: ColorRect = $ScreenFX/Rect
@onready var background: LevelBackground = _ensure_node("Background", LevelBackground, -10)


## Background and FX look empty in the editor (they're filled at runtime), so
## recreate them if they were removed, instead of crashing.
func _ensure_node(node_name: String, type: Variant, z: int) -> Node:
	var n := get_node_or_null(node_name)
	if n == null:
		push_warning("Level: '%s' node missing from the scene; recreating it." % node_name)
		n = type.new()
		n.name = node_name
		n.z_index = z
		add_child(n)
		if node_name == "Background":
			move_child(n, 0)
	return n


func _ready() -> void:
	process_physics_priority = 100
	_parse_map()
	_build_terrain()
	_spawn_objects()
	_spawn_hints()
	_parse_waves()
	_respawn_pad = PAD_SCENE.instantiate()
	_respawn_pad.position = start_pos - Vector2(8, 0)
	_respawn_pad.z_index = 1
	objects.add_child(_respawn_pad)
	_respawn_pad.sprite.texture = REBOUND_PAD_TEX
	if LevelBackground.has_city(level_number):
		background.setup_city(level_number, Vector2(map_w * TILE, map_h * TILE))
	else:
		background.setup(Vector2(map_w * TILE, map_h * TILE))
	player.fx_parent = fx
	player.landed.connect(_on_player_landed)
	camera.setup(player, Rect2(0, 0, map_w * TILE, map_h * TILE))
	hud.show_title(level_number, level_title)
	_start_attempt()
	camera.snap_to_target()


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	match phase:
		Phase.PLAYING:
			if _rebound_pressed():
				_kill_player(true)
			else:
				_record()
				echo.apply_tick(tick)
				_update_flyers(tick)
				tick += 1
				_update_interactions()
				_check_flyers()
				_check_hazards()
				_check_exit()
		Phase.DYING:
			_update_interactions()
			_phase_t -= delta
			if _phase_t <= 0.0:
				_finish_death()
		Phase.RESPAWNING:
			_update_interactions()
			_phase_t -= delta
			if _phase_t <= 0.0:
				phase = Phase.PLAYING
				player.activate()
		Phase.COMPLETE:
			_phase_t -= delta
			if _phase_t <= 0.0 and not _complete_sent:
				_complete_sent = true
				completed.emit()
				Game.level_completed()
	_update_hud()


func _process(delta: float) -> void:
	_decor_t += delta
	if _decor_t > 0.35:
		_decor_t = 0.0
		for d in _decor:
			if d.has_meta("anim") and randf() < 0.5:
				d.frame = d.frame ^ 1
	var mat: ShaderMaterial = screen_fx.material
	var g: float = mat.get_shader_parameter("glitch")
	if g > 0.0:
		mat.set_shader_parameter("glitch", maxf(g - delta * 2.5, 0.0))
	var f: float = mat.get_shader_parameter("flash")
	if f > 0.0:
		mat.set_shader_parameter("flash", maxf(f - delta * 4.0, 0.0))


func _rebound_pressed() -> bool:
	if player.input_override != null:
		return player.input_override.get("rebound", false)
	return Input.is_action_just_pressed("rebound")


# ------------------------------------------------------------------ attempts

func _start_attempt() -> void:
	attempt += 1
	tick = 0
	_rec_pos.clear()
	_rec_code.clear()
	_echo_on_pad = false
	_clear_flyers()
	player.respawn(start_pos)
	echo.rewind(_new_echo)
	if _new_echo:
		Game.sfx("echo", -2.0)
		echo.set_tag("ATTEMPT %d" % _echo_attempt)
		hud.toast("ATTEMPT %d LIVES ON AS YOUR ECHO" % _echo_attempt)
	_new_echo = false
	phase = Phase.RESPAWNING
	_phase_t = RESPAWN_TIME
	_bounce_back_effect()


## The respawn is a literal bounce back: a cyan spring flings the robot
## out of the floor and it lands ready to go. Purely visual, so recordings
## (which start after this) are unaffected.
func _bounce_back_effect() -> void:
	var first := attempt == 1
	var v := player.visual
	v.position = Vector2(0, 6)
	var tw := player.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void:
		_respawn_pad.fire(false)
		Game.sfx("respawn", -6.0)
		player.squash(Vector2(0.6, 1.5)))
	tw.tween_property(v, "position:y", -30.0 if not first else -14.0, 0.24).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(v, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		player.squash(Vector2(1.45, 0.6))
		player.dust.restart()
		player.dust.emitting = true
		if not first:
			camera.shake(1.0, 0.1))


func _record() -> void:
	if _rec_pos.size() >= MAX_RECORD_TICKS:
		return
	_rec_pos.append(player.position)
	_rec_code.append(player.anim_code())


func _kill_player(voluntary := false, by_flyer := false) -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.DYING
	_phase_t = DEATH_TIME
	Game.failures += 1
	_death_spot = player.position
	var line: Array = REBOUND_LINE if voluntary else FAIL_LINES[(Game.failures - 1) % FAIL_LINES.size()]
	var sub: String = line[1]
	if _rec_pos.size() < MIN_ECHO_TICKS:
		sub = "TOO QUICK TO LEAVE AN ECHO"
	hud.fail_message(line[0], sub)
	_leave_fail_mark(player.position)
	player.die()
	Game.sfx("rebound" if voluntary else "death")
	if by_flyer:
		Game.sfx("flyer_kill")  # queued after the death clip: "skill issue"
	camera.shake(4.0, 0.3)
	_screen_glitch(1.0, Color("#f472b6"), 0.55)
	_burst(player.position + Vector2(0, -7), Color("#f472b6"), 14)


func _finish_death() -> void:
	# Edge case: tiny recordings would make a useless echo; keep the old one.
	if _rec_pos.size() >= MIN_ECHO_TICKS:
		echo.load_recording(_rec_pos, _rec_code)
		_new_echo = true
		_echo_attempt = attempt
		_echo_helped = false
	elif echo.has_recording():
		hud.toast("TOO SHORT - OLD ECHO KEPT")
	_start_attempt()


func _complete() -> void:
	phase = Phase.COMPLETE
	_phase_t = 0.9
	player.state = Player.State.FROZEN
	player.velocity = Vector2.ZERO
	Game.sfx("complete")
	_screen_glitch(0.4, Color("#34d399"), 0.4)
	_burst(exit_portal.position + Vector2(0, -11), Color("#34d399"), 24, STAR_TEX)
	var tw := player.create_tween()
	tw.tween_property(player.visual, "scale", Vector2(0.0, 2.5), 0.35).set_ease(Tween.EASE_IN)
	hud.toast("SIGNAL ESCAPED")


# ------------------------------------------------------------------ flyers

func _parse_waves() -> void:
	for line in waves:
		var f := line.split("|")
		if f.size() < 5:
			push_warning("Level: bad wave line '%s'" % line)
			continue
		_waves.append({
			"y": int(f[0]) * TILE + TILE / 2.0, "first": int(f[1]),
			"interval": maxi(1, int(f[2])), "speed": float(f[3]), "bob": float(f[4]),
		})


## Spawns, moves and despawns flyers for this tick. Every attempt sees the
## same wave because positions depend only on the tick.
func _update_flyers(t: int) -> void:
	for w in _waves.size():
		var wave: Dictionary = _waves[w]
		var since: int = t - wave.first
		if since >= 0 and since % wave.interval == 0:
			var key := "%d:%d" % [w, since / wave.interval]
			if not flyers.has(key):
				var f: Flyer = FLYER_SCENE.instantiate()
				f.setup(t, Vector2(map_w * TILE + 8, wave.y), wave.speed, wave.bob, key)
				objects.add_child(f)
				flyers[key] = f
	for key in flyers.keys():
		var f: Flyer = flyers[key]
		if f.popped:
			continue
		f.place(t)
		if f.position.x < -16.0:
			f.queue_free()
			flyers.erase(key)


## Landing on a flyer bounces you and pops it; any other contact kills.
## The echo pops flyers it stomped in its recording, so the wave stays in
## step with the replay. Otherwise the echo passes through (it can't react).
func _check_flyers() -> void:
	if flyers.is_empty():
		return
	var i := tick - 1
	var echo_stomping := false
	if echo.active and echo.visible and i >= 1 and i < echo.positions.size():
		echo_stomping = echo.positions[i].y > echo.positions[i - 1].y
	for f: Flyer in flyers.values():
		if f.popped:
			continue
		var top := f.hitbox().position.y
		if echo_stomping and echo.hitbox().intersects(f.hitbox()) \
				and echo.hitbox().end.y - (echo.positions[i].y - echo.positions[i - 1].y) <= top + STOMP_SLACK:
			_pop_flyer(f, false)
			continue
		if player.state != Player.State.ACTIVE or not player.hitbox().intersects(f.hitbox()):
			continue
		var feet := player.hitbox().end.y
		if player.velocity.y > 0.0 and feet - player.velocity.y / 60.0 <= top + STOMP_SLACK:
			player.bounce(STOMP_VELOCITY)
			_pop_flyer(f, true)
		else:
			_kill_player(false, true)
			return


func _pop_flyer(f: Flyer, by_player: bool) -> void:
	f.pop()
	Game.sfx("bounce", 0.0 if by_player else -10.0, 0.1)
	Game.sfx("flyer_pop", 2.0 if by_player else -8.0, 0.12)
	if by_player:
		camera.shake(1.5, 0.12)
		_burst(f.position, Color("#22d3ee"), 8)


func _clear_flyers() -> void:
	for f in flyers.values():
		f.queue_free()
	flyers.clear()


# ------------------------------------------------------------------ interactions

func _update_interactions() -> void:
	var player_box := player.hitbox()
	var player_presses := player.state == Player.State.ACTIVE
	var echo_presses := echo.active and echo.visible
	var echo_box := echo.hitbox()

	var channel_ok := {}
	var channel_seen := {}
	for plate in plates:
		var by_echo := echo_presses and plate.is_pressed_by(echo_box)
		var p := (player_presses and plate.is_pressed_by(player_box)) or by_echo
		if by_echo and not _echo_helped and phase == Phase.PLAYING:
			_echo_helped = true
			hud.toast("ATTEMPT %d IS HOLDING THE DOOR FOR YOU" % _echo_attempt)
		plate.set_pressed(p)
		channel_seen[plate.channel] = true
		channel_ok[plate.channel] = channel_ok.get(plate.channel, true) and p
	for door in doors:
		var open: bool = channel_seen.has(door.channel) and channel_ok[door.channel]
		var inside := player.state != Player.State.DEAD and door.body_rect().intersects(player_box.grow(1.0))
		door.set_open(open, inside)

	if phase != Phase.PLAYING:
		return
	for pad in pads:
		if player.velocity.y >= -20.0 and pad.touches(player_box):
			player.bounce()
			pad.fire(true)
			camera.shake(1.5, 0.12)
	# echo just replays positions, but the pad still reacts when it passes
	var on_pad := false
	if echo_presses:
		for pad in pads:
			if pad.touches(echo_box):
				on_pad = true
				if not _echo_on_pad:
					pad.fire(false)
	_echo_on_pad = on_pad


func _check_hazards() -> void:
	var box := player.hitbox()
	if player.position.y > map_h * TILE + 24:
		_kill_player()
		return
	for r in spike_rects:
		if r.intersects(box):
			_kill_player()
			return


func _check_exit() -> void:
	if exit_portal and exit_portal.trigger_rect().intersects(player.hitbox()):
		_complete()


func _on_player_landed(impact: float) -> void:
	if impact > 220.0:
		camera.shake(1.5, 0.12)


# ------------------------------------------------------------------ effects

func _screen_glitch(amount: float, flash_col: Color, flash_amount: float) -> void:
	var mat: ShaderMaterial = screen_fx.material
	mat.set_shader_parameter("glitch", amount)
	mat.set_shader_parameter("flash", flash_amount)
	mat.set_shader_parameter("flash_color", flash_col)


func _burst(at: Vector2, c: Color, count: int, tex: Texture2D = DOTS_TEX) -> void:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.position = at
	p.amount = count
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = c
	p.emitting = true
	fx.add_child(p)
	get_tree().create_timer(1.0, false).timeout.connect(p.queue_free)


func _update_hud() -> void:
	var status := "NONE"
	var col := Color("#4b5578")
	var prog := 0.0
	if echo.has_recording():
		if phase == Phase.RESPAWNING:
			status = "SYNCING"
			col = Color("#a5f3fc")
		elif echo.active:
			var left := float(echo.length_ticks() - tick) / 60.0
			status = "REPLAYING %.1fS" % maxf(left, 0.0)
			col = Color("#22d3ee")
			prog = echo.progress(tick)
		else:
			status = "ENDED"
			col = Color("#8f9bbf")
			prog = 1.0
	hud.set_stats(attempt, status, col, prog)


# ------------------------------------------------------------------ building

func _parse_map() -> void:
	var lines := map.strip_edges().split("\n")
	for l in lines:
		var s := l.strip_edges()
		grid.append(s)
		map_w = maxi(map_w, s.length())
	map_h = grid.size()
	for y in map_h:
		grid[y] = grid[y].rpad(map_w, ".")


func cell(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= map_w or y >= map_h:
		return "#" if (x < 0 or x >= map_w) else "."
	return grid[y][x]


func is_solid(x: int, y: int) -> bool:
	return cell(x, y) == "#"


func _build_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_number * 7919
	for y in map_h:
		for x in map_w:
			var c := cell(x, y)
			var at := Vector2(x * TILE, y * TILE)
			match c:
				"#":
					var mask := 0
					if not is_solid(x, y - 1) and y > 0:
						mask |= 1
					if not is_solid(x + 1, y):
						mask |= 2
					if not is_solid(x, y + 1) and y < map_h - 1:
						mask |= 4
					if not is_solid(x - 1, y):
						mask |= 8
					terrain.add_solid(at, mask)
					_maybe_decor(x, y, mask, rng)
				"-":
					terrain.add_platform(at)
				"^":
					terrain.add_spike(at, true)
					spike_rects.append(Rect2(at + Vector2(1, 3), Vector2(6, 5)))
				"v":
					terrain.add_spike(at, false)
					spike_rects.append(Rect2(at + Vector2(1, 0), Vector2(6, 5)))
	terrain.queue_redraw()
	_build_collision()


## Every fall leaves something behind: a small mark where the attempt ended.
func _leave_fail_mark(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = FAIL_MARK_TEX
	s.position = Vector2(at.x, minf(at.y, map_h * TILE - 4) - 5)
	s.z_index = -1
	s.modulate = Color(1, 1, 1, 0)
	terrain.add_child(s)
	var tw := s.create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(s, "modulate:a", 0.55, 0.4)


func _maybe_decor(x: int, y: int, mask: int, rng: RandomNumberGenerator) -> void:
	var tall_free := mask & 1 and cell(x, y - 1) == "." and cell(x, y - 2) == "." and cell(x, y - 3) == "." and cell(x + 1, y - 1) == "."
	if tall_free and rng.randf() < 0.035:
		var tree := Sprite2D.new()
		tree.texture = TREES_TEX
		tree.modulate = TileLayer.SILHOUETTE
		tree.hframes = 2
		tree.frame = rng.randi_range(0, 1)
		tree.centered = false
		tree.position = Vector2(x * TILE, (y - 3) * TILE)
		tree.z_index = -2
		terrain.add_child(tree)
		return
	var top_free := mask & 1 and cell(x, y - 1) == "." and cell(x, y - 2) == "."
	var bottom_free := mask & 4 and cell(x, y + 1) == "."
	if top_free and rng.randf() < 0.09:
		var idx: int = [0, 2][rng.randi_range(0, 1)]
		_add_decor(idx, Vector2(x * TILE, (y - 1) * TILE), idx < 4)
	elif bottom_free and rng.randf() < 0.07:
		var idx2 := 6 if rng.randf() < 0.6 else 7
		_add_decor(idx2, Vector2(x * TILE, (y + 1) * TILE), false)


func _add_decor(idx: int, at: Vector2, animated: bool) -> void:
	var s := Sprite2D.new()
	s.texture = DECOR_TEX
	s.hframes = 8
	s.frame = idx
	s.centered = false
	s.position = at
	s.z_index = -1
	s.modulate = TileLayer.SILHOUETTE
	if animated:
		s.set_meta("anim", true)
	terrain.add_child(s)
	_decor.append(s)


## Merges solid cells into as few rectangles as possible.
func _build_collision() -> void:
	var used := {}
	for y in map_h:
		for x in map_w:
			if not is_solid(x, y) or used.has(Vector2i(x, y)):
				continue
			var w := 0
			while x + w < map_w and is_solid(x + w, y) and not used.has(Vector2i(x + w, y)):
				w += 1
			var h := 1
			var can_grow := true
			while can_grow and y + h < map_h:
				for i in w:
					if not is_solid(x + i, y + h) or used.has(Vector2i(x + i, y + h)):
						can_grow = false
						break
				if can_grow:
					h += 1
			for yy in h:
				for xx in w:
					used[Vector2i(x + xx, y + yy)] = true
			_add_box(solids, Rect2(x * TILE, y * TILE, w * TILE, h * TILE), false)
	# one-way platforms (runs of '-')
	for y in map_h:
		var x := 0
		while x < map_w:
			if cell(x, y) == "-":
				var w := 0
				while cell(x + w, y) == "-":
					w += 1
				_add_box(solids, Rect2(x * TILE, y * TILE, w * TILE, 4), true)
				x += w
			else:
				x += 1


func _add_box(body: StaticBody2D, r: Rect2, one_way: bool) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	cs.one_way_collision = one_way
	body.add_child(cs)


func _spawn_objects() -> void:
	for y in map_h:
		var x := 0
		while x < map_w:
			var c := cell(x, y)
			var floor_y := (y + 1) * TILE
			match c:
				"P":
					start_pos = Vector2(x * TILE + 4, floor_y)
				"E":
					exit_portal = EXIT_SCENE.instantiate()
					exit_portal.position = Vector2(x * TILE + 4, floor_y)
					objects.add_child(exit_portal)
				"o":
					var pad: BouncePad = PAD_SCENE.instantiate()
					pad.position = Vector2(x * TILE, floor_y)
					objects.add_child(pad)
					pads.append(pad)
					x += 1  # pads are two tiles wide
				"a", "b":
					var plate: PressurePlate = PLATE_SCENE.instantiate()
					plate.setup(0 if c == "a" else 1)
					plate.position = Vector2(x * TILE, floor_y)
					objects.add_child(plate)
					plates.append(plate)
					x += 1
				"A", "B":
					var h := 1
					while y + h < map_h and not is_solid(x, y + h):
						h += 1
					var door: Door = DOOR_SCENE.instantiate()
					door.setup(0 if c == "A" else 1, h * TILE)
					door.position = Vector2(x * TILE, y * TILE)
					objects.add_child(door)
					doors.append(door)
			x += 1


func _spawn_hints() -> void:
	for h in hints:
		var parts := h.split("|", true, 1)
		if parts.size() < 2:
			continue
		var xy := parts[0].split(",")
		var lbl := Label.new()
		lbl.text = parts[1]
		lbl.position = Vector2(int(xy[0]) * TILE, int(xy[1]) * TILE)
		lbl.modulate = Color(0.65, 0.55, 0.98, 0.75)
		lbl.z_index = -8
		fx.add_child(lbl)
