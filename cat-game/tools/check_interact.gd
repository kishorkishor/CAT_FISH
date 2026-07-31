extends SceneTree
## Asserts the walk-up prompts: the right thing is picked out of a crowd, it
## highlights, the prompt reads, and pressing use runs its verb.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player = world.get_node("Entities/Player")
	var interactor: Node2D = world.get_node("Interactor")
	var clock := root.get_node("Clock")
	var entities := world.get_node("Entities")

	var labelled := get_nodes_in_group("interactable")
	_ok(labelled.size() >= 8, "%d props announce themselves" % labelled.size())

	# --- nothing nearby says nothing --------------------------------------
	player.global_position = Vector2(3104, 700)
	await process_frame
	_ok(interactor.prompt().is_empty(), "open grass shows no prompt")

	# --- walking up to the cottage ----------------------------------------
	var cottage = entities.get_node("HouseBlue")
	player.global_position = cottage.global_position + Vector2(0, 20)
	await process_frame
	_ok(interactor.focus() == cottage, "the cottage is picked up when stood at")
	_ok(interactor.prompt().contains("cottage") and interactor.prompt().contains("sleep"),
		"prompt reads: %s" % interactor.prompt())
	var art = cottage.get_node("Sprite")
	_ok(art.modulate != Color.WHITE, "the focused prop is highlighted")

	# --- the nearest one wins ---------------------------------------------
	var lamp = entities.get_node("LampPost")
	player.global_position = lamp.global_position + Vector2(0, 8)
	await process_frame
	_ok(interactor.focus() == lamp, "the nearest prop wins when several are close")
	_ok(art.modulate == Color.WHITE, "the old focus stops being highlighted")

	# --- use runs the prop's verb, not the tool's -------------------------
	player.global_position = cottage.global_position + Vector2(0, 20)
	interactor.tool = Tools.HOE
	await process_frame
	var day_before: int = clock.day
	var ev := InputEventAction.new()
	ev.action = "use"
	ev.pressed = true
	interactor._unhandled_input(ev)
	await process_frame
	_ok(clock.day == day_before + 1, "use at the cottage slept instead of tilling the doorstep")

	# --- and away from it, the hoe is a hoe again -------------------------
	var farm: Node2D = world.get_node("Farm")
	var water: TileMapLayer = world.get_node("Water")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	player.global_position = water.map_to_local(centre + Vector2i(1, -4))
	await process_frame
	var plots_before: int = farm.plots.size()
	interactor._unhandled_input(ev)
	_ok(farm.plots.size() == plots_before + 1, "away from props the hoe still tills")

	quit(failures)
