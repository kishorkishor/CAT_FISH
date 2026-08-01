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
	# These probes are not about where farming is allowed - check_fields covers
	# that. Mark the working area out so they can get on with what they do test.
	world.get_node("Fields").fields.append(Rect2i(38, 24, 24, 40))
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

	# --- a seed goes in damp ------------------------------------------------
	_ok(plot.water >= 1.0, "sowing leaves the soil watered")

	# --- growth needs water --------------------------------------------------
	# The weather is driven by hand here rather than rolled. Emitting day_passed
	# re-rolls the sky first, so "hold it dry for six days" turned into "hold it
	# dry for however many days the RNG felt like" and the assertion drifted.
	var weather := root.get_node("Weather")
	var stage_before: int = plot.stage
	for i in 6:
		weather.kind = weather.Kind.CLEAR
		plot.water = 0.0
		farm._on_day_passed(2 + i)
	_ok(plot.stage == stage_before, "a dry plot does not grow")

	# ...and it wilts, then dies, rather than sitting dry forever.
	_ok(plot.dead, "left dry past its grace, the plant died")

	# --- a watered one ripens -------------------------------------------------
	farm.clear(plot_cell)
	farm.plots.erase(plot_cell)
	_ok(farm.till(plot_cell), "re-tilled the plot")
	_ok(farm.plant(plot_cell, crop), "re-planted a carrot")
	plot = farm.plots[plot_cell]

	var days := 0
	while not crop.is_ripe(plot.stage) and days < 20:
		farm.water(plot_cell)
		clock.day_passed.emit(20 + days)
		days += 1
	_ok(crop.is_ripe(plot.stage), "watered %d days -> ripe (stage %d)" % [days, plot.stage])
	_ok(not plot.dead, "and it is alive")

	# What the soil wakes up like is the weather's business, so roll days until
	# each sky has had a turn rather than asserting whichever one came up. Doing
	# it the other way passed for weeks and then failed the first rainy morning.
	# Rain has to be worth checking the forecast for: it refills the tank you
	# would otherwise have walked round with a can to fill.
	for wanted_wet in [false, true]:
		weather.kind = weather.Kind.RAIN if wanted_wet else weather.Kind.CLEAR
		plot.stage = 0
		plot.dead = false
		plot.wilt_days = 0
		plot.water = 0.0
		farm._on_day_passed(40)
		var topped_up: bool = plot.water > 0.0
		_ok(topped_up == wanted_wet,
			"a %s morning leaves the tank %s (%.2f)" % [
				weather.name_of(), "topped up" if topped_up else "empty", plot.water])
	# The dry run above will have killed it again; put it back for the harvest.
	plot.dead = false
	plot.stage = crop.stage_count() - 1
	farm.water(plot_cell)

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
