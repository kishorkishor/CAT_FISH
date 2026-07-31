extends SceneTree
## Boots the world, drops the cat into open water swimming east, saves one frame.
##
##   godot --path . --resolution 540x960 --script res://tools/shot_swim.gd -- <out.png>
##
## Not compatible with --headless - there is no rendered frame to capture.

const SETTLE_FRAMES := 30

var _frames := 0
var _out := ""
var _placed := false


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else "swim_shot.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if not _placed and _frames > 2:
		var world := root.get_node("World")
		var water: TileMapLayer = world.get_node("Water")
		var player = world.get_node("Entities/Player")
		var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
		for step in range(1, water.grid_size):
			var cell := centre + Vector2i(step, step)
			if water.is_fully_secondary(cell):
				player.global_position = water.map_to_local(cell)
				break
		Input.action_press("move_right")
		_placed = true
	if _frames < SETTLE_FRAMES:
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png(_out)
	if err != OK:
		push_error("save_png failed: %d" % err)
	else:
		print("wrote %s" % _out)
	return true
