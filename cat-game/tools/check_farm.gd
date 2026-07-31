extends SceneTree
## Runs a whole farming life-cycle headless: till, plant, water, let days pass,
## harvest, then build something and save and reload the lot.

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
	var clock := root.get_node("Clock")
	var farm: Node2D = world.get_node("Farm")
	var buildings: Node2D = world.get_node("Buildings")
	var land: TileMapLayer = world.get_node("Land")

	# A grass cell well inside the island.
	var centre := Vector2i(land.grid_size / 2, land.grid_size / 2)
	var plot_cell := centre + Vector2i(2, 2)

	_ok(farm.can_till(plot_cell), "grass can be tilled")
	_ok(farm.till(plot_cell), "tilled a plot")
	_ok(not farm.till(plot_cell), "the same cell cannot be tilled twice")

	var crop: CropData = load("res://data/crops/carrot.tres")
	_ok(crop != null and crop.stage_count() == 4, "carrot has 4 stages")
	_ok(farm.plant(plot_cell, crop), "planted a carrot")

	var plot = farm.plots[plot_cell]

	# --- growth needs water ------------------------------------------------
	clock.day_passed.emit(2)
	_ok(plot.stage == 0, "a dry plot does not grow")

	var days := 0
	while not crop.is_ripe(plot.stage) and days < 20:
		farm.water(plot_cell)
		clock.day_passed.emit(3 + days)
		days += 1
	_ok(crop.is_ripe(plot.stage), "watered %d days -> ripe (stage %d)" % [days, plot.stage])
	_ok(not plot.watered, "soil dries overnight")

	# --- harvest ------------------------------------------------------------
	var before: int = game.count_of("carrot")
	var picked: int = farm.harvest(plot_cell)
	_ok(picked > 0, "harvested %d carrots" % picked)
	_ok(game.count_of("carrot") == before + picked, "the carrots went into the bag")
	_ok(farm.plots[plot_cell].crop == null, "a non-regrowing crop clears its plot")

	# --- a regrowing crop keeps its plant ----------------------------------
	var tomato: CropData = load("res://data/crops/tomato.tres")
	farm.plant(plot_cell, tomato)
	farm.plots[plot_cell].stage = tomato.stage_count() - 1
	farm.harvest(plot_cell)
	_ok(farm.plots[plot_cell].crop != null and farm.plots[plot_cell].stage == tomato.regrow_to,
		"a regrowing tomato drops back to stage %d instead of dying" % tomato.regrow_to)

	# --- selling ------------------------------------------------------------
	game.money = 0
	var earned: int = game.sell_all()
	_ok(earned > 0 and game.money == earned, "sold the harvest for %d coins" % earned)
	_ok(game.count_of("carrot_seed") > 0, "seeds are not sold by the sell-all button")

	# --- building -----------------------------------------------------------
	var entry: BuildEntry = load("res://data/build/palm.tres")
	var build_cell := centre + Vector2i(-3, -3)
	game.money = 1000
	_ok(buildings.can_place(build_cell, entry), "can build on clear grass")
	_ok(buildings.place(build_cell, entry), "placed a %s" % entry.display_name)
	_ok(game.money == 1000 - entry.cost, "building charged %d coins" % entry.cost)
	_ok(not buildings.can_place(build_cell, entry), "cannot build on an occupied cell")
	_ok(not buildings.can_place(plot_cell, entry), "cannot build on a farm plot")
	game.money = 0
	_ok(not buildings.can_place(centre + Vector2i(-5, -5), entry), "cannot build without coins")

	# --- water depth --------------------------------------------------------
	var water: TileMapLayer = world.get_node("Water")
	var seen := {}
	for step in range(0, water.grid_size / 2):
		seen[water.depth_at(centre + Vector2i(step, step))] = true
	_ok(seen.has(0) and seen.has(1) and seen.has(2) and seen.has(3),
		"walking out to sea crosses land, shallows, mid and deep")

	# --- save round trip ----------------------------------------------------
	game.money = 777
	game.save_game()
	var plots_before: int = farm.plots.size()
	var built_before: int = buildings.placed.size()
	farm.plots.clear()
	buildings.placed.clear()
	game.money = 0
	_ok(game.load_game(), "save file reloaded")
	_ok(game.money == 777, "money survived the round trip")
	_ok(farm.plots.size() == plots_before, "%d plots survived" % plots_before)
	_ok(buildings.placed.size() == built_before, "%d buildings survived" % built_before)

	quit(failures)
