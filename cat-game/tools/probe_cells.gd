extends SceneTree
func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var water: TileMapLayer = world.get_node("Water")
	var land: TileMapLayer = world.get_node("Land")
	var spots := [
		["rowboat",  Vector2i(43, 85)],
		["rowboat2", Vector2i(44, 86)],
		["palm1",    Vector2i(41, 73)],
		["palm2",    Vector2i(55, 73)],
		["palm1b",   Vector2i(40, 75)],
		["palm2b",   Vector2i(56, 75)],
		["rock1",    Vector2i(30, 60)],
		["rock2",    Vector2i(66, 58)],
		["rock1b",   Vector2i(28, 55)],
		["rock2b",   Vector2i(68, 52)],
	]
	for s in spots:
		var cell: Vector2i = s[1]
		var pos := water.map_to_local(cell)
		var w := "water" if water.is_fully_secondary(cell) else "sand"
		var g := "+grass" if land._corner_mask(cell.x, cell.y) == 15 else ""
		print("%-10s cell=%s pos=%s  %s%s" % [s[0], cell, pos, w, g])
	quit()
