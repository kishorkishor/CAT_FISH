extends SceneTree
## The axe, the wood it yields, and the buildings that eat it.
##
## The decision the axe exists to pose: keep watering a tree and keep picking
## fruit, or cash it in for timber - and letting it die of thirst first has to be
## the worst of the three, not a free harvest.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var farm: Node2D = world.get_node("Farm")
	var buildings: Node2D = world.get_node("Buildings")
	var water: TileMapLayer = world.get_node("Water")
	var game := root.get_node("Game")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var tree: CropData = load("res://data/crops/lemon.tres")
	var carrot: CropData = load("res://data/crops/carrot.tres")

	_ok(tree.is_tree, "the lemon is fellable")
	_ok(not carrot.is_tree, "a carrot is not")
	_ok(game.items.has("wood"), "wood is a real item")

	# --- only trees fall to the axe ------------------------------------------
	var veg := centre + Vector2i(3, 2)
	farm.till(veg)
	farm.plant(veg, carrot)
	_ok(farm.fell(veg) == 0, "the axe does nothing to a carrot")
	_ok(farm.action_at(veg, Tools.AXE).is_empty(), "and says nothing about it")

	# --- a grown living tree pays best ---------------------------------------
	var cell := centre + Vector2i(5, 2)
	farm.till(cell)
	farm.plant(cell, tree)
	var plot = farm.plots[cell]
	plot.stage = tree.stage_count() - 1
	var grown: int = farm.fell_value(cell)

	# ...a sapling less...
	plot.stage = 0
	var sapling: int = farm.fell_value(cell)

	# ...and a dead one least of all.
	plot.stage = tree.stage_count() - 1
	plot.dead = true
	var dead: int = farm.fell_value(cell)
	plot.dead = false

	_ok(grown > sapling, "a grown tree gives more than a sapling (%d vs %d)" % [grown, sapling])
	_ok(grown > dead, "and more alive than dead (%d vs %d)" % [grown, dead])
	_ok(dead == tree.wood_dead, "a dead one gives exactly its dead value (%d)" % dead)

	# --- the prompt puts the number in front of you ---------------------------
	plot.stage = tree.stage_count() - 1
	var says: String = farm.action_at(cell, Tools.AXE)
	_ok(says.contains(str(grown)), "the prompt names the yield: '%s'" % says)
	plot.dead = true
	var says_dead: String = farm.action_at(cell, Tools.AXE)
	_ok(says_dead.contains(str(dead)), "and drops when it dies: '%s'" % says_dead)
	plot.dead = false

	# --- felling actually pays -----------------------------------------------
	var before: int = game.count_of("wood")
	var got: int = farm.fell(cell)
	_ok(got == grown, "felling it yielded the %d it promised" % got)
	_ok(game.count_of("wood") == before + got, "and the wood went into the bag")
	_ok(farm.plots.has(cell) and farm.plots[cell].crop == null,
		"the plot is left bare, not destroyed")

	# --- buildings want timber ------------------------------------------------
	var cottage: BuildEntry = load("res://data/build/cottage.tres")
	_ok(cottage.wood > 0, "the cottage costs %d wood as well as coins" % cottage.wood)
	game.money = 99999
	game.bag["wood"] = 0
	var spot := centre + Vector2i(-6, -6)
	_ok(not buildings.can_place(spot, cottage), "cannot build it with no timber")
	_ok(buildings.why_not(spot, cottage).contains("wood"),
		"and says why: '%s'" % buildings.why_not(spot, cottage))

	# Coins must not be taken when the build fails on materials.
	var coins_before: int = game.money
	_ok(not buildings.place(spot, cottage), "the build is refused")
	_ok(game.money == coins_before, "and no coins were taken")

	game.bag["wood"] = cottage.wood
	_ok(buildings.place(spot, cottage), "with timber in hand it goes up")
	_ok(game.count_of("wood") == 0, "and the timber was spent")

	# --- sell-everything leaves the shed alone --------------------------------
	game.bag["wood"] = 10
	game.bag["sardine"] = 2
	game.sell_all()
	_ok(game.count_of("wood") == 10, "sell-everything keeps the wood")
	_ok(game.count_of("sardine") == 0, "and still sells the fish")

	quit(failures)
