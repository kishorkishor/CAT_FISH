extends SceneTree
var _frames := 0
var _out := ""
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else "storm.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())
func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		root.get_node("Weather").kind = 3
		root.get_node("Clock").hour = 18.5
		var world := root.get_node("World")
		var water: TileMapLayer = world.get_node("Water")
		var player = world.get_node("Entities/Player")
		player.global_position = water.to_global(water.map_to_local(Vector2i(water.grid_size/2, water.grid_size/2) + Vector2i(0, 20)))
		player.get_node("Camera2D").zoom = Vector2(1.6, 1.6)
	if _frames < 90:
		return false
	root.get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	return true
