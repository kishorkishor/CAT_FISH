extends SceneTree
## Walks the cat out to sea and asserts each depth band plays its own animation,
## sinks by its own amount, and is standing on the water colour that matches.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var sea: TileMapLayer = world.get_node("Sea")
	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)

	# One representative cell per band, found by walking east.
	var sample := {}
	for step in range(0, water.grid_size / 2):
		var cell := centre + Vector2i(step, 0)
		var d: int = water.depth_at(cell)
		if not sample.has(d):
			sample[d] = cell
	_ok(sample.size() == 4, "found a cell for all four bands")

	var expect := {0: "walk", 1: "walk", 2: "swim", 3: "deep"}
	var sinks := {}
	for depth in [0, 1, 2, 3]:
		if not sample.has(depth):
			continue
		player.global_position = water.to_global(water.map_to_local(sample[depth]))
		Input.action_press("move_right")
		for i in 8:
			await physics_frame
		var anim: String = sprite.animation
		var clipped: bool = sprite.material.get_shader_parameter(&"clip_enabled")
		sinks[depth] = sprite.offset.y
		_ok(anim.begins_with(expect[depth]),
			"depth %d plays %s (wanted %s*)" % [depth, anim, expect[depth]])
		_ok(clipped == (depth > 0), "depth %d waterline clip = %s" % [depth, clipped])

	# Each step out to sea must sink the cat further than the last.
	var ordered := true
	for depth in [1, 2, 3]:
		if sinks.has(depth) and sinks.has(depth - 1) and sinks[depth] <= sinks[depth - 1]:
			ordered = false
	_ok(ordered, "the cat sinks further at every depth: %s" % [sinks])

	# The tile under the cat has to agree with the rules: wadeable water is
	# painted by the shallow set, swimmable water is bare deep sea.
	if sample.has(1):
		_ok(sea.get_cell_source_id(sample[1]) >= 0 and not sea.is_fully_secondary(sample[1]),
			"the wadeable band is painted as shallows")
	if sample.has(3):
		_ok(sea.is_fully_secondary(sample[3]), "the deep band is open ocean on the sea layer")

	quit(failures)
