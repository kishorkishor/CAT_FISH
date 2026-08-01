extends SceneTree
## There is somewhere to sail to, it is reachable, and it is worth the trip.

var failures := 0

## The three outer islands, as offsets in cells from the middle of the patch.
const ISLES: Array[Vector2i] = [
	Vector2i(-34, -26), Vector2i(37, -34), Vector2i(-30, 34),
]


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var water: TileMapLayer = world.get_node("Water")
	var land: TileMapLayer = world.get_node("Land")
	var entities: Node2D = world.get_node("Entities")
	var middle: int = water.grid_size / 2

	for isle in ISLES:
		var mid := Vector2i(middle + isle.x, middle + isle.y)
		var dry := 0
		for dy in range(-8, 9):
			for dx in range(-6, 7):
				if land._corner_mask(mid.x + dx, mid.y + dy) == 15:
					dry += 1
		_ok(dry > 20, "island at %s has %d cells of dry land" % [isle, dry])

		# It has to be separate land, not a lump joined onto home. Somewhere on the
		# line between the two shores there must be water, or you could walk it.
		var wet := 0
		for step in range(1, 40):
			var t := float(step) / 40.0
			var cell := Vector2i(
				middle + roundi(isle.x * t), middle + roundi(isle.y * t))
			if int(water.depth_at(cell)) > 0:
				wet += 1
		_ok(wet > 4, "%d cells of open water lie between it and home" % wet)

		# Its own shelf: the beach must not read as open ocean, or the deep fish
		# would be biting two paces from the sand.
		var shore := Vector2i(mid.x + 7, mid.y)
		_ok(int(water.depth_at(shore)) <= 2,
			"the water off its beach shelves properly (depth %d)"
				% water.depth_at(shore))

	# --- and there is something on them worth taking --------------------------
	var timber := 0
	var out_there := 0
	for node in entities.get_children():
		if not node.name.begins_with("Isle"):
			continue
		out_there += 1
		if node.get("wood") != null and node.wood > 0:
			timber += node.wood
	_ok(out_there >= 12, "%d things are standing out on the islands" % out_there)
	_ok(timber >= 40, "worth %d wood in total if you sail out and fell it" % timber)

	# --- a wild tree really does fall to the axe ------------------------------
	var interactor: Node2D = world.get_node("Interactor")
	var player = world.get_node("Entities/Player")
	var game := root.get_node("Game")
	var tree: Node2D = null
	for node in entities.get_children():
		if node.name.begins_with("IsleTree"):
			tree = node
			break
	_ok(tree != null, "found a wild tree")
	if tree != null:
		player.global_position = tree.global_position
		interactor.tool = Tools.AXE
		await physics_frame
		await physics_frame
		var before: int = game.count_of("wood")
		var expected: int = tree.wood
		interactor._use()
		await process_frame
		_ok(game.count_of("wood") == before + expected,
			"felling it gave %d wood" % (game.count_of("wood") - before))
		_ok(not is_instance_valid(tree) or tree.is_queued_for_deletion(),
			"and the tree is gone")

	quit(failures)
