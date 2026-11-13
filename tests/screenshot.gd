extends Node
## Renders a scene and saves screenshots.
## Usage: godot --path . res://tests/screenshot.tscn -- <scene> <out_prefix> <frame,frame,...> [pause] [fails=N]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("fails="):
			Game.failures = int(a.split("=")[1])
	var scene: Node = load(args[0]).instantiate()
	get_parent().add_child.call_deferred(scene)
	var frames: Array = Array(args[2].split(",")).map(func(x: String) -> int: return int(x))
	var f := 0
	for target in frames:
		while f < target:
			await get_tree().process_frame
			f += 1
		if "pause" in args:
			var ev := InputEventAction.new()
			ev.action = "pause"
			ev.pressed = true
			Input.parse_input_event(ev)
			for i in 5:
				await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [args[1], target])
	get_tree().quit()
