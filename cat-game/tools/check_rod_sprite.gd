extends SceneTree
## Holding the rod should change what the cat looks like, and only that.
var failures := 0
func _ok(p: bool, m: String) -> void:
	print(("ok   " if p else "FAIL ") + m)
	if not p: failures += 1

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player = world.get_node("Entities/Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var interactor: Node2D = world.get_node("Interactor")
	var water: TileMapLayer = world.get_node("Water")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)

	_ok(player.frames_rod != null, "the rod set is attached")
	_ok(player.frames_rod.has_animation("walk_south"), "and it can walk")

	player.global_position = water.map_to_local(centre)
	interactor.tool = Tools.HAND
	Input.action_press("move_right")
	for i in 6: await physics_frame
	_ok(sprite.sprite_frames == player.frames_upright, "empty-pawed the cat uses the plain set")

	interactor.tool = Tools.ROD
	for i in 6: await physics_frame
	_ok(player.holding_rod, "the player knows the rod is out")
	_ok(sprite.sprite_frames == player.frames_rod, "and is drawn carrying it")
	_ok(sprite.animation.begins_with("walk"), "still walking normally (%s)" % sprite.animation)

	# sprinting is a different rig and must win
	Input.action_press("run")
	for i in 6: await physics_frame
	_ok(sprite.sprite_frames == player.frames_sprint, "sprinting still drops to four legs")
	Input.action_release("run")

	# deep water has no rod frames, so it must fall back rather than freeze
	var deep := Vector2i(-1, -1)
	for step in range(1, water.grid_size / 2):
		if water.depth_at(centre + Vector2i(step, 0)) >= 2:
			deep = centre + Vector2i(step, 0)
			break
	player.global_position = water.map_to_local(deep)
	for i in 8: await physics_frame
	_ok(sprite.sprite_frames == player.frames_upright, "in deep water it falls back to the swim set")
	_ok(sprite.animation.begins_with("swim") or sprite.animation.begins_with("deep"),
		"and actually swims (%s)" % sprite.animation)
	Input.action_release("move_right")
	quit(failures)
