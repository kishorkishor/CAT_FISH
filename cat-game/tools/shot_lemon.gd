extends SceneTree
var _frames := 0
var _out := ""
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else "lemon.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())
func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		var world := root.get_node("World")
		var farm: Node2D = world.get_node("Farm")
		var water: TileMapLayer = world.get_node("Water")
		var player = world.get_node("Entities/Player")
		var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
		var lemon: CropData = load("res://data/crops/lemon.tres")
		for s in 4:
			var cell := centre + Vector2i(s * 2 - 3, -2)
			farm.till(cell)
			farm.plant(cell, lemon)
			farm.plots[cell].stage = s
			farm._refresh_sprite(farm.plots[cell])
		farm.queue_redraw()
		player.global_position = water.to_global(water.map_to_local(centre + Vector2i(-1, 3)))
		player.get_node("Camera2D").zoom = Vector2(2.0, 2.0)
	if _frames < 25:
		return false
	root.get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	return true
