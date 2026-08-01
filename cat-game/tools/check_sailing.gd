extends SceneTree
## Getting on the boat, steering it, fishing off it, and getting back ashore
## without ending up standing in the sea.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	await process_frame


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player = world.get_node("Entities/Player")
	var boat = world.get_node("Entities/Boat")
	var sailing: Node2D = world.get_node("Sailing")
	var interactor: Node2D = world.get_node("Interactor")
	var water: TileMapLayer = world.get_node("Water")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)

	_ok(boat != null, "there is a boat in the world")
	_ok(not sailing.sailing, "and the cat starts ashore")
	_ok(interactor.body() == player, "so tools follow the cat")

	# --- you cannot board from across the island -----------------------------
	player.global_position = water.to_global(water.map_to_local(centre))
	await physics_frame
	_ok(not sailing.can_board(), "cannot board a boat that is nowhere near")

	# --- walk up to it and climb on ------------------------------------------
	player.global_position = boat.global_position + Vector2(10, 0)
	await physics_frame
	_ok(sailing.can_board(), "standing at the boat, boarding is offered")
	sailing._climb_aboard()
	await physics_frame
	_ok(sailing.sailing, "aboard")
	_ok(not player.visible, "the cat is put away")
	_ok(interactor.body() == boat, "and tools now follow the boat")
	_ok(interactor.at_sea, "the interactor knows it is afloat")

	# The camera has to come along, or you sail off the edge of the screen.
	var cam: Camera2D = boat.get_node_or_null("Camera2D")
	_ok(cam != null and cam.is_current(), "the camera came aboard")

	# --- it sails -------------------------------------------------------------
	var start: Vector2 = boat.global_position
	Input.action_press("move_right")
	for i in 30:
		await physics_frame
	Input.action_release("move_right")
	_ok(boat.global_position.x > start.x + 8.0,
		"it moves under sail (%.0f px)" % (boat.global_position.x - start.x))
	_ok(boat.facing() == "east", "and faces where it is going (%s)" % boat.facing())

	# It has mass: a boat should not reach full speed as fast as the cat does.
	_ok(boat.acceleration < player.acceleration,
		"a boat is slower to get going than a cat (%.0f vs %.0f)"
			% [boat.acceleration, player.acceleration])

	# --- the rod works at sea, the rest does not ------------------------------
	interactor.tool = Tools.HOE
	await physics_frame
	var plots_before: int = world.get_node("Farm").plots.size()
	interactor._use()
	_ok(world.get_node("Farm").plots.size() == plots_before,
		"the hoe does nothing over open water")

	# --- and back ashore -------------------------------------------------------
	sailing._step_off()
	await physics_frame
	_ok(not sailing.sailing, "stepped off")
	_ok(player.visible, "the cat is back")
	_ok(interactor.body() == player, "tools follow the cat again")
	_ok(not interactor.at_sea, "and the sea flag cleared")

	# The landing must be dry. Dumping the cat into the water on disembark is the
	# bug this search exists to prevent.
	var cell := water.local_to_map(water.to_local(player.global_position))
	_ok(int(water.depth_at(cell)) == 0,
		"it put the cat on dry land, not in the sea (depth %d)" % water.depth_at(cell))

	var cam2: Camera2D = player.get_node_or_null("Camera2D")
	_ok(cam2 != null and cam2.is_current(), "and the camera came back")

	quit(failures)
