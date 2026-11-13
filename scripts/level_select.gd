extends Control
## Level select: every level is open; finished ones are marked CLEAR.

const CLEAR_COLOR := Color("#34d399")

@onready var grid: GridContainer = $Grid
@onready var back_btn: Button = $Back


func _ready() -> void:
	get_tree().paused = false
	$Background.setup(Vector2(320, 180))
	for i in Game.LEVELS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%d  %s" % [i + 1, Game.level_title(i)]
		if Game.is_cleared(i):
			b.text += "  CLEAR"
			b.add_theme_color_override("font_color", CLEAR_COLOR)
		b.pressed.connect(_on_level.bind(i))
		b.focus_entered.connect(func() -> void: Game.sfx("select", -8.0))
		grid.add_child(b)
	back_btn.pressed.connect(_on_back)
	back_btn.focus_entered.connect(func() -> void: Game.sfx("select", -8.0))
	(grid.get_child(0) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_back()


func _on_level(index: int) -> void:
	Game.sfx("select")
	Game.start_level(index)


func _on_back() -> void:
	Game.sfx("select")
	Game.to_main_menu()
