extends SceneTree
## Prints an ASCII terrain map of a cell range: G grass, s sand, ~ water.
##   godot --headless --path . --script res://tools/probe_map.gd -- x0 x1 y0 y1
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var x0 := int(a[0]); var x1 := int(a[1]); var y0 := int(a[2]); var y1 := int(a[3])
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var water: TileMapLayer = world.get_node("Water")
	var land: TileMapLayer = world.get_node("Land")
	var header := "     "
	for x in range(x0, x1 + 1):
		header += str(x % 10)
	print(header)
	for y in range(y0, y1 + 1):
		var row := "%4d " % y
		for x in range(x0, x1 + 1):
			if water.is_fully_secondary(Vector2i(x, y)):
				row += "~"
			elif land._corner_mask(x, y) == 15:
				row += "G"
			else:
				row += "s"
		print(row)
	quit()
