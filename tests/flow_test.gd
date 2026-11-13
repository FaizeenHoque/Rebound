extends Node
## Checks menu -> intro -> (skip) -> level 1 -> restart flow, the ending,
## and the level select.


func _ready() -> void:
	# survive scene changes: live directly under the root, not as the scene
	await get_tree().process_frame
	reparent(get_tree().root)
	var dummy := Node.new()
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	await get_tree().create_timer(0.2).timeout
	Game.persist = false
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
	Game.current_level = Game.LEVELS.size() - 1
	Game.level_completed()
	await get_tree().create_timer(1.2).timeout
	print("after final level: ", get_tree().current_scene.name)
	Game.to_level_select()
	await get_tree().create_timer(1.2).timeout
	s = get_tree().current_scene
	var buttons: Array = s.grid.get_children()
	print("level select: ", s.name, " buttons=", buttons.size(), "/", Game.LEVELS.size(),
		" cleared_marked=", (buttons[Game.LEVELS.size() - 1] as Button).text.ends_with("CLEAR"))
	(buttons[2] as Button).pressed.emit()
	await get_tree().create_timer(1.2).timeout
	s = get_tree().current_scene
	print("picked level 3: ", s.name, " current_level=", Game.current_level, " title=", s.level_title)
	get_tree().quit()
