extends Node
## Checks menu -> intro -> (skip) -> level 1 -> restart flow.


func _ready() -> void:
	# survive scene changes: live directly under the root, not as the scene
	await get_tree().process_frame
	reparent(get_tree().root)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	await get_tree().create_timer(0.2).timeout
	Game.start_game()
	await get_tree().create_timer(1.2).timeout
	var s := get_tree().current_scene
	print("after PLAY: ", s.name)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(1.2).timeout
	s = get_tree().current_scene
	print("after skip: ", s.name, " attempt=", s.get("attempt"))
	Game.restart_level()
	await get_tree().create_timer(1.2).timeout
	s = get_tree().current_scene
	print("after restart: ", s.name, " attempt=", s.get("attempt"), " echo=", s.echo.has_recording())
	Game.current_level = 2
	Game.level_completed()
	await get_tree().create_timer(1.2).timeout
	print("after final level: ", get_tree().current_scene.name)
	get_tree().quit()
