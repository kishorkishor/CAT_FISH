extends SceneTree
## The cat aboard, out on the water.
var _dir := "."
var _frames := 0


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_dir = argv[0] if argv.size() > 0 else "."
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		var world := root.get_node("World")
		var water: TileMapLayer = world.get_node("Water")
		var player = world.get_node("Entities/Player")
		var boat = world.get_node("Entities/Boat")
		var sailing: Node2D = world.get_node("Sailing")
		root.get_node("Clock").hour = 12.0
		# Out past the shelf, where a boat belongs.
		var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
		var spot := centre
		for step in range(4, water.grid_size / 2):
			var c := centre + Vector2i(step, 0)
			if int(water.depth_at(c)) >= 2:
				spot = c
				break
		boat.global_position = water.to_global(water.map_to_local(spot))
		player.global_position = boat.global_position
		sailing._climb_aboard()
		Input.action_press("move_right")
		return false
	if _frames < 30:
		return false
	var path := "%s/boat.png" % _dir
	print("wrote %s" % path if root.get_texture().get_image().save_png(path) == OK else "failed")
	return true
