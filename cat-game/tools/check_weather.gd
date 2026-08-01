extends SceneTree
## Weather has to change what you do, not just how it looks.
var failures := 0
func _ok(p: bool, m: String) -> void:
	print(("ok   " if p else "FAIL ") + m)
	if not p: failures += 1

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var weather := root.get_node("Weather")
	var farm: Node2D = world.get_node("Farm")
	var land: TileMapLayer = world.get_node("Land")
	var casting: Node2D = world.get_node("Casting")

	# every kind should turn up over many rolls
	var seen := {}
	for i in 400:
		weather.roll()
		seen[weather.kind] = true
	_ok(seen.size() == 4, "all four kinds occur over 400 days (%d seen)" % seen.size())

	# --- rain waters the farm overnight -----------------------------------
	var centre := Vector2i(land.grid_size / 2, land.grid_size / 2)
	var cell := centre + Vector2i(4, 4)
	farm.till(cell)
	farm.plant(cell, load("res://data/crops/carrot.tres"))
	var plot = farm.plots[cell]

	weather.kind = weather.Kind.CLEAR
	plot.water = 1.0
	plot.stage = 0
	farm._on_day_passed(2)
	_ok(plot.water < 1.0, "on a clear day the soil dries out")

	weather.kind = weather.Kind.RAIN
	plot.water = 0.0
	plot.stage = 0
	plot.dead = false
	plot.wilt_days = 0
	farm._on_day_passed(3)
	_ok(plot.water > 0.0, "rain fills the tank, so the can can stay in the shed")

	# a crop left alone should still ripen through a wet week
	plot.stage = 0
	plot.days_in_stage = 0
	for day in 8:
		farm._on_day_passed(4 + day)
	_ok(plot.crop.is_ripe(plot.stage), "a wet week ripens a crop with no watering at all")

	# --- storms bring the deep fish inshore -------------------------------
	weather.kind = weather.Kind.CLEAR
	_ok(weather.depth_bonus() == 0, "clear weather gives no depth bonus")
	weather.kind = weather.Kind.STORM
	_ok(weather.depth_bonus() == 1, "a storm reaches one band deeper")

	var bamboo: RodData = load("res://data/rods/bamboo.tres")
	game.rod = bamboo
	weather.kind = weather.Kind.CLEAR
	var deepest_calm := 0
	for i in 200:
		deepest_calm = maxi(deepest_calm, casting._pick_fish(1).min_depth)
	weather.kind = weather.Kind.STORM
	var deepest_storm := 0
	for i in 200:
		deepest_storm = maxi(deepest_storm, casting._pick_fish(1 + weather.depth_bonus()).min_depth)
	_ok(deepest_storm > deepest_calm,
		"a storm puts deeper fish on the hook (%d vs %d)" % [deepest_storm, deepest_calm])

	# --- light and saving ---------------------------------------------------
	weather.kind = weather.Kind.CLEAR
	var bright: Color = weather.light_scale()
	weather.kind = weather.Kind.STORM
	_ok(weather.light_scale().v < bright.v, "a storm is darker than a clear day")

	game.save_game()
	weather.kind = weather.Kind.CLEAR
	_ok(game.load_game(), "reloaded")
	_ok(weather.kind == weather.Kind.STORM, "the forecast survived the round trip")
	quit(failures)
