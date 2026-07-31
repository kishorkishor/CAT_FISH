extends SceneTree
## Walks the player from the island centre out to sea and reports where the
## swim state actually takes over.

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")

	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var last := ""
	for step in range(0, water.grid_size / 2):
		var cell := centre + Vector2i(step, step)
		player.global_position = water.map_to_local(cell)
		await physics_frame
		await physics_frame
		var tag := "WATER" if player.in_water else "land "
		if tag != last:
			print("cell offset +%-2d -> %s   (in_water=%s)" % [step, tag, player.in_water])
			last = tag
	print("done")
	quit()
