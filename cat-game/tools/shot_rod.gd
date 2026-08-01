extends SceneTree
var _frames := 0
var _out := ""
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else "rod.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())
func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		var world := root.get_node("World")
		world.get_node("Interactor").tool = Tools.ROD
		var water: TileMapLayer = world.get_node("Water")
		var player = world.get_node("Entities/Player")
		var centre := Vector2i(water.grid_size/2, water.grid_size/2)
		var shore := 0
		for j in range(1, 40):
			if water.is_fully_secondary(centre + Vector2i(0, j)):
				shore = j; break
		player.global_position = water.to_global(water.map_to_local(centre + Vector2i(0, shore - 3)))
		player.get_node("Camera2D").zoom = Vector2(3.0, 3.0)
		Input.action_press("move_down")
	if _frames < 24:
		return false
	root.get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	return true
