extends SceneTree
## Water is a level that drains, bigger plants drink faster, and running dry
## warns before it kills.

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
	var water: TileMapLayer = world.get_node("Water")
	var weather := root.get_node("Weather")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var crop: CropData = load("res://data/crops/carrot.tres")
	var tree: CropData = load("res://data/crops/lemon.tres")

	# --- a bigger plant drinks faster ---------------------------------------
	_ok(tree.dry_days(0) >= tree.dry_days(tree.stage_count() - 1),
		"a lemon sapling lasts %d days, a grown one %d"
			% [tree.dry_days(0), tree.dry_days(tree.stage_count() - 1)])
	_ok(tree.thirst(tree.stage_count() - 1) > tree.thirst(0),
		"and so drinks faster once grown")

	var cell := centre + Vector2i(2, 2)
	farm.till(cell)
	farm.plant(cell, crop)
	var plot = farm.plots[cell]

	# --- the tank drains ------------------------------------------------------
	_ok(plot.water >= 1.0, "sown with a full tank")
	weather.kind = weather.Kind.CLEAR
	var before: float = plot.water
	farm._on_day_passed(2)
	_ok(plot.water < before, "a day drains it (%.2f -> %.2f)" % [before, plot.water])

	# --- watering tops it back up --------------------------------------------
	_ok(farm.water(cell), "the can refills it")
	_ok(plot.water >= 1.0, "back to full")
	_ok(not farm.water(cell), "and refuses a tank that is already full")

	# --- dry means wilt, then death, with warning in between ------------------
	plot.water = 0.0
	plot.wilt_days = 0
	plot.dead = false
	var died_on := -1
	for day in range(1, crop.wilt_grace + 4):
		weather.kind = weather.Kind.CLEAR
		plot.water = 0.0
		farm._on_day_passed(10 + day)
		if plot.dead and died_on < 0:
			died_on = day
		if not plot.dead:
			_ok(plot.wilting(), "day %d dry: wilting, still alive" % day)
	_ok(died_on > 1, "it took %d dry days to die, not one" % died_on)
	_ok(died_on == crop.wilt_grace + 1,
		"death lands exactly after its %d day grace" % crop.wilt_grace)

	# --- watering a wilting plant saves it -----------------------------------
	farm.clear(cell)
	farm.plots.erase(cell)
	farm.till(cell)
	farm.plant(cell, crop)
	plot = farm.plots[cell]
	weather.kind = weather.Kind.CLEAR
	plot.water = 0.0
	farm._on_day_passed(30)
	_ok(plot.wilting() and not plot.dead, "wilting after a dry night")
	farm.water(cell)
	_ok(plot.wilt_days == 0 and not plot.wilting(), "a drink resets the clock")

	# --- the readout actually says the number ---------------------------------
	var line: String = farm.describe(cell)
	_ok(line.contains("carrot") and line.contains("water in"),
		"the plot explains itself: '%s'" % line)
	plot.water = 0.0
	plot.wilt_days = 1
	line = farm.describe(cell)
	_ok(line.contains("WILTING") and line.contains("dies in"),
		"and warns when it is dying: '%s'" % line)

	# --- a dead plant cannot be harvested or revived --------------------------
	plot.dead = true
	plot.stage = crop.stage_count() - 1
	_ok(farm.harvest(cell) == 0, "a dead plant yields nothing")
	_ok(farm.describe(cell).contains("dead"), "and says so")

	quit(failures)
