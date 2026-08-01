extends SceneTree
## Presses real keys and checks the game reacts.
##
## Every other probe reaches into a node and calls its handler directly, which
## proves the handler works and proves nothing about whether a keypress ever gets
## there. This one goes through the input map and the whole unhandled-input
## chain, so a swallowed event or a missing binding fails here and only here.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _press(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await physics_frame
	await process_frame
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await physics_frame


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	# These probes are not about where farming is allowed - check_fields covers
	# that. Mark the working area out so they can get on with what they do test.
	world.get_node("Fields").fields.append(Rect2i(38, 24, 24, 40))
	var player = world.get_node("Entities/Player")
	var interactor: Node2D = world.get_node("Interactor")
	var farm: Node2D = world.get_node("Farm")
	var water: TileMapLayer = world.get_node("Water")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)

	# --- the bindings exist at all ----------------------------------------
	for action in ["use", "tool_next", "cycle", "sleep", "panel"]:
		_ok(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
			"%s is bound to something" % action)

	player.global_position = water.to_global(water.map_to_local(centre + Vector2i(1, -6)))
	for i in 4:
		await physics_frame

	# --- Tab walks the belt -------------------------------------------------
	var started: int = interactor.tool
	await _press(KEY_TAB)
	_ok(interactor.tool != started,
		"Tab changed the tool (%s -> %s)" % [Tools.NAMES[started], Tools.NAMES[interactor.tool]])

	# --- E with the hoe tills ----------------------------------------------
	interactor.tool = Tools.HOE
	await physics_frame
	var cell: Vector2i = interactor.target_cell()
	var before: int = farm.plots.size()
	await _press(KEY_E)
	_ok(farm.plots.size() == before + 1,
		"pressing E with the hoe tilled the ground (%d -> %d plots)" % [before, farm.plots.size()])
	_ok(farm.plots.has(cell), "and it tilled the cell the cat was facing")

	# --- E with the paw sows ------------------------------------------------
	interactor.tool = Tools.HAND
	await physics_frame
	await _press(KEY_E)
	_ok(farm.plots.has(cell) and farm.plots[cell].crop != null,
		"pressing E with the paw sowed a seed")

	# --- and the cat animates for it ----------------------------------------
	_ok(player.is_acting(), "the cat is mid-action from a real keypress")

	quit(failures)
