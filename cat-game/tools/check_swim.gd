extends SceneTree
## Teleports the player into open water and reports the state it lands in.

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var shadow = player.get_node("Shadow")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)

	for label in ["land", "water"]:
		var offset := 0 if label == "land" else 9
		player.global_position = water.map_to_local(centre + Vector2i(offset, offset))
		Input.action_press("move_right")
		for i in 6:
			await physics_frame
		print("%-6s in_water=%-6s anim=%-12s frames=%d shadow=%s" % [
			label, player.in_water, sprite.animation,
			sprite.sprite_frames.get_frame_count(sprite.animation), shadow.visible])
	quit()
