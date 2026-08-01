extends SceneTree
## Asserts the camera is pixel-art safe: smoothing off, limits fenced to the map.

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player = world.get_node("Entities/Player")
	var cam: Camera2D = player.get_node("Camera2D")
	var failures := 0

	if cam.position_smoothing_enabled:
		print("FAIL position smoothing is on - subpixel crawl at integer scale")
		failures += 1
	else:
		print("ok   smoothing off")

	# Camera2D defaults its limits to +/-10^7; anything that large means unset.
	var limits := [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	if limits.any(func(v): return abs(v) > 1000000):
		print("FAIL limits not set: %s" % [limits])
		failures += 1
	else:
		print("ok   limits %s" % [limits])
	if cam.limit_left >= cam.limit_right or cam.limit_top >= cam.limit_bottom:
		print("FAIL limits inverted")
		failures += 1

	# The camera has to actually be allowed to sit where the cat starts, which is
	# the middle of the island. This is what catches the world drifting out of its
	# own fence rather than the fence merely being some valid rectangle.
	var here: Vector2 = player.global_position
	if here.x < cam.limit_left or here.x > cam.limit_right \
			or here.y < cam.limit_top or here.y > cam.limit_bottom:
		print("FAIL the cat starts outside the camera limits: %s not in %s" % [here, limits])
		failures += 1
	else:
		print("ok   the cat starts inside the camera limits")

	# The world is shifted so the middle of the patch lands on the origin - that is
	# what makes the scene open on the island in the editor instead of on empty sea
	# thousands of pixels away. A hand-set offset and a changed grid_size drift
	# apart silently, so check it rather than trust it.
	var water: TileMapLayer = world.get_node("Water")
	var centre := water.to_global(water.map_to_local(
		Vector2i(water.grid_size / 2, water.grid_size / 2)))
	if centre.length() > float(water.tile_set.tile_size.x):
		print("FAIL the island centre is %s, not on the origin - fix World.position" % centre)
		failures += 1
	else:
		print("ok   the island centre sits on the origin (%s)" % centre)

	quit(failures)
