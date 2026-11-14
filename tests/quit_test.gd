extends Node
## Quits the way the QUIT button / window close does; run with --verbose to check for leaks.
## Pass a scene after "--" to quit from inside it (e.g. a level full of chattering flyers):
##   godot --path . res://tests/quit_test.tscn -- res://scenes/levels/level_7.tscn


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		get_parent().add_child.call_deferred(load(args[0]).instantiate())
		await get_tree().create_timer(12.0).timeout
	await get_tree().create_timer(1.0).timeout
	Game.quit_game()
