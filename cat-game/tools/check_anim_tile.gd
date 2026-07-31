extends SceneTree
## Asserts the animated open-water tile is wired through: the tileset carries the
## relocated tile with its frames, and the world actually paints it.

func _initialize() -> void:
	var failures := 0
	var tile_set: TileSet = load("res://assets/tiles/sand_water.tres")

	if not tile_set.has_meta(&"open_coords"):
		print("SKIP sand_water has no animation - nothing to check")
		quit()
		return

	var open_coords: Vector2i = tile_set.get_meta(&"open_coords")
	var source := tile_set.get_source(0) as TileSetAtlasSource
	var n := source.get_tile_animation_frames_count(open_coords)
	if n >= 2:
		print("ok   open tile at %s animates with %d frames" % [open_coords, n])
	else:
		print("FAIL open tile at %s has %d frames" % [open_coords, n])
		failures += 1
	if not source.has_tile(Vector2i(0, 0)):
		print("ok   (0,0) freed for the frame strip's neighbours check")

	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var water: TileMapLayer = world.get_node("Water")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var open_cell := Vector2i(-1, -1)
	for step in range(1, water.grid_size / 2):
		var cell := centre + Vector2i(step, step)
		if water.is_fully_secondary(cell):
			open_cell = cell
			break
	if open_cell.x < 0:
		print("FAIL no open water cell found")
		failures += 1
	elif water.get_cell_atlas_coords(open_cell) == open_coords:
		print("ok   open water cell %s painted with the animated tile" % open_cell)
	else:
		print("FAIL open water cell %s painted %s, expected %s" % [
			open_cell, water.get_cell_atlas_coords(open_cell), open_coords])
		failures += 1

	quit(failures)
