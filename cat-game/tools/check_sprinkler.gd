extends SceneTree
## A sprinkler has to actually save you the walk: plots in range wake up full,
## plots out of range do not, and the area it covers reads as round on the ground
## rather than as a long stripe.

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
	var farm: Node2D = world.get_node("Farm")
	var buildings: Node2D = world.get_node("Buildings")
	var water: TileMapLayer = world.get_node("Water")
	var weather := root.get_node("Weather")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var crop: CropData = load("res://data/crops/carrot.tres")

	var entry: BuildEntry = load("res://data/build/sprinkler.tres")
	_ok(entry != null and entry.waters_radius > 0,
		"the sprinkler declares a radius of %d" % entry.waters_radius)

	# It goes on bare ground, with plots around it.
	var post := centre + Vector2i(0, -8)
	var game := root.get_node("Game")
	game.money = 9999
	# Buildings cost timber as well as coins now.
	game.bag["wood"] = 99
	_ok(buildings.place(post, entry), "placed a sprinkler")

	var near := post + Vector2i(1, 0)
	var far := post + Vector2i(9, 0)
	for cell in [near, far]:
		farm.till(cell)
		farm.plant(cell, crop)

	_ok(farm.is_sprinkled(near), "the plot beside it is covered")
	_ok(not farm.is_sprinkled(far), "a plot nine cells away is not")

	# The coverage has to be round on screen. One cell east and two cells south
	# are the same distance on the ground, because a cell is twice as wide as it
	# is tall - if only one of them is covered, the radius is being measured in
	# raw cell coordinates and the spray is a stripe.
	_ok(farm.is_sprinkled(post + Vector2i(1, 0)) == farm.is_sprinkled(post + Vector2i(0, 2)),
		"one cell across covers the same as two cells down")

	# --- it waters overnight ------------------------------------------------
	weather.kind = weather.Kind.CLEAR
	farm.plots[near].water = 0.0
	farm.plots[far].water = 0.0
	farm._on_day_passed(5)
	_ok(farm.plots[near].water > 0.0, "the covered plot woke up watered")
	_ok(farm.plots[far].water <= 0.0, "the far plot did not")

	# ...and keeps a plant alive that would otherwise have died.
	for day in range(6, 14):
		weather.kind = weather.Kind.CLEAR
		farm.plots[far].water = 0.0
		farm._on_day_passed(day)
	_ok(not farm.plots[near].dead, "the covered plant is still alive after a week")
	_ok(farm.plots[far].dead, "the neglected one is not")

	# --- taking it down stops the water --------------------------------------
	_ok(buildings.demolish(post), "took the sprinkler down")
	_ok(not farm.is_sprinkled(near), "and the coverage went with it")

	quit(failures)
