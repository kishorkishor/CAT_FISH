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

	quit(failures)
