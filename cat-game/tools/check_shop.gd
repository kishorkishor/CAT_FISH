extends SceneTree
## Asserts the loop actually closes: sell for coins, buy the next rod, and the
## new rod both widens the band and reaches fish the old one could not.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var game := root.get_node("Game")
	var casting: Node2D = world.get_node("Casting")
	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")
	var interactor: Node2D = world.get_node("Interactor")
	var shop: CanvasLayer = world.get_node("Shop")

	# --- the ladder --------------------------------------------------------
	_ok(game.rods.size() == 3, "%d rods in the catalogue" % game.rods.size())
	_ok(game.rod.id == "bamboo", "the cat starts on the bamboo rod")
	var next: RodData = game.next_rod()
	_ok(next.id == "oak", "the shop offers the oak rod next, not the master")

	game.money = 10
	_ok(not game.buy_rod(next), "cannot buy a rod you cannot afford")
	game.money = next.price + 5
	_ok(game.buy_rod(next), "bought the %s" % next.display_name)
	_ok(game.money == 5, "the coins were taken")
	_ok(game.rod.id == "oak", "the oak rod is in paw")
	_ok(game.next_rod().id == "master", "and the master rod is now the offer")
	_ok(not game.buy_rod(load("res://data/rods/bamboo.tres")), "cannot buy backwards")

	# --- the rod changes the fight ----------------------------------------
	var bamboo: RodData = load("res://data/rods/bamboo.tres")
	var master: RodData = load("res://data/rods/master.tres")
	_ok(master.band_bonus > bamboo.band_bonus, "a better rod widens the safe band")
	_ok(master.max_depth > bamboo.max_depth, "a better rod reaches deeper water")

	# --- and reaches fish the old one cannot ------------------------------
	var shallow_only := []
	var deep_too := []
	for fish in casting.fish_pool:
		if fish.min_depth <= bamboo.max_depth:
			shallow_only.append(fish.display_name)
		if fish.min_depth <= master.max_depth:
			deep_too.append(fish.display_name)
	_ok(deep_too.size() > shallow_only.size(),
		"bamboo reaches %d fish, master reaches %d" % [shallow_only.size(), deep_too.size()])
	_ok(not shallow_only.has("tuna") and deep_too.has("tuna"),
		"the tuna is only reachable with the master rod")

	# --- casting respects the rod -----------------------------------------
	# Stand on the south shore and cast with each rod; the better one should put
	# the line into deeper water from the same spot.
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var shore := -1
	for j in range(1, water.grid_size / 2):
		if water.is_fully_secondary(centre + Vector2i(0, j)):
			shore = j
			break
	player.global_position = water.to_global(water.map_to_local(centre + Vector2i(0, shore - 2)))
	await physics_frame

	game.rod = bamboo
	var near_cell: Vector2i = casting._find_water_ahead()
	game.rod = master
	var far_cell: Vector2i = casting._find_water_ahead()
	var near_depth: int = water.depth_at(near_cell) if near_cell.x >= 0 else -1
	var far_depth: int = water.depth_at(far_cell) if far_cell.x >= 0 else -1
	_ok(near_depth >= 1, "the bamboo rod can still reach the shallows (depth %d)" % near_depth)
	_ok(far_depth > near_depth,
		"the master rod casts deeper from the same spot (%d vs %d)" % [far_depth, near_depth])

	# --- the stall opens ---------------------------------------------------
	var keeper = world.get_node("Entities/Shopkeeper")
	player.global_position = keeper.global_position + Vector2(0, 14)
	await process_frame
	await process_frame
	_ok(interactor.focus() == keeper, "the shopkeeper is picked up when stood at")
	var ev := InputEventAction.new()
	ev.action = "use"
	ev.pressed = true
	interactor._unhandled_input(ev)
	await process_frame
	_ok(shop.visible, "use at the shopkeeper opened the stall")
	_ok(root.get_tree().paused, "the world pauses while trading")
	shop.close()
	_ok(not root.get_tree().paused, "and starts again on leaving")

	# --- selling still works through the stall ----------------------------
	game.add_item("tuna", 2)
	game.money = 0
	var earned: int = game.sell_all()
	_ok(earned == 120, "sold 2 tuna for %d coins" % earned)

	quit(failures)
