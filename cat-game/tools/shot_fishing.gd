extends SceneTree
## Boots the world, casts from the south shore, saves one frame mid-fight.
##
##   godot --path . --resolution 540x960 --script res://tools/shot_fishing.gd -- <out.png>
##
## Not compatible with --headless - there is no rendered frame to capture.

var _out := ""
var _stage := 0
var _frames := 0


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else "fishing_shot.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var world := root.get_node("World")
	var casting: Node2D = world.get_node("Casting")

	if _stage == 0:
		var water: TileMapLayer = world.get_node("Water")
		var player = world.get_node("Entities/Player")
		var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
		for j in range(1, water.grid_size / 2):
			if water.is_fully_secondary(centre + Vector2i(0, j)):
				player.global_position = water.map_to_local(centre + Vector2i(0, j - 3))
				break
		casting.wait_min = 0.2
		casting.wait_max = 0.3
		var ev := InputEventAction.new()
		ev.action = "cast"
		ev.pressed = true
		casting._unhandled_input(ev)
		_stage = 1
		return false

	if _stage == 1:
		for child in casting.get_children():
			if child is CanvasLayer:
				_stage = 2
				_frames = 0
		return false

	if _frames < 45:  # let the fight settle into a readable state
		Input.action_press("reel")
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png(_out)
	if err != OK:
		push_error("save_png failed: %d" % err)
	else:
		print("wrote %s" % _out)
	return true
