extends SceneTree
## Asserts the bay carve: spawn is land, the bay mouth is open water, and
## turning the bay off restores a whole island.

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var water: TileMapLayer = world.get_node("Water")
	var land: TileMapLayer = world.get_node("Land")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var failures := 0

	# Spawn cell must be solid land on both layers.
	if water.is_fully_secondary(centre):
		print("FAIL spawn cell is open water")
		failures += 1
	else:
		print("ok   spawn is land")

	# A cell partway into the bay: inside the island radius, but carved to water.
	# The island shape lives in weighted space (vertical distances scaled by
	# iso_ratio), so a shape-space offset converts to cells by dividing y back out.
	# Script properties read back as Variant, hence the explicit types here.
	var bay_angle: float = water.bay_angle_deg
	var ratio: float = water.iso_ratio
	var into_bay: Vector2 = Vector2.from_angle(deg_to_rad(bay_angle)) * (float(water.island_radius) - 2.0)
	into_bay.y /= ratio
	var bay_cell := centre + Vector2i(into_bay.round())
	if water.is_fully_secondary(bay_cell):
		print("ok   bay mouth is open water at %s" % bay_cell)
	else:
		print("FAIL bay mouth still land at %s" % bay_cell)
		failures += 1

	# The opposite shore, same distance, must still be land - the carve is local.
	var opposite := centre - Vector2i(into_bay.round())
	if water.is_fully_secondary(opposite):
		print("FAIL opposite shore was carved too at %s" % opposite)
		failures += 1
	else:
		print("ok   opposite shore intact")

	# Sand ring: the land layer's bay is carved wider, so partway in there is a
	# cell where grass is gone but sand remains.
	# Along the bay axis the water carve stops at island_radius - bay_depth and the
	# land carve at its own island_radius - bay_depth; sand survives between the
	# two, so sample the midpoint of that band.
	var inner_water: float = float(water.island_radius) - float(water.bay_depth)
	var inner_land: float = float(land.island_radius) - float(land.bay_depth)
	var ring_off: Vector2 = Vector2.from_angle(deg_to_rad(bay_angle)) * ((inner_water + inner_land) * 0.5)
	ring_off.y /= ratio
	var ring := centre + Vector2i(ring_off.round())
	var sand_here: bool = not water.is_fully_secondary(ring)
	var grass_here: bool = land._corner_mask(ring.x, ring.y) != 0
	if sand_here and not grass_here:
		print("ok   sand rings the bay at %s" % ring)
	else:
		print("note ring cell %s sand=%s grass=%s" % [ring, sand_here, grass_here])

	# Disabling the bay restores the mouth to land.
	water.bay_depth = 0.0
	if water.is_fully_secondary(bay_cell):
		print("FAIL bay_depth=0 did not restore the coast")
		failures += 1
	else:
		print("ok   bay_depth=0 restores the island")

	quit(failures)
