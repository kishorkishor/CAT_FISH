extends SceneTree
## Walks the whole goal chain by doing the things it asks for, and checks the
## rewards land, the order holds, and it survives a save.

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
	var goals := root.get_node("Goals")
	var events := root.get_node("Events")
	var farm: Node2D = world.get_node("Farm")
	var buildings: Node2D = world.get_node("Buildings")
	var land: TileMapLayer = world.get_node("Land")

	_ok(goals.chain.size() == 7, "%d goals in the chain" % goals.chain.size())
	_ok(goals.current().id == "01_catch", "it opens on '%s'" % goals.current().title)
	_ok(not goals.line().is_empty(), "the HUD line reads: %s" % goals.line())

	# --- goal 1: catch something ------------------------------------------
	var money_before: int = game.money
	var fish: FishData = load("res://data/fish/sardine.tres")
	events.fish_caught.emit(fish)
	_ok(goals.current().id == "02_sell", "catching one fish advanced the chain")
	_ok(game.money == money_before + 20, "the reward was paid (%d coins)" % game.money)

	# --- an unrelated event must not advance anything ---------------------
	var index_before: int = goals.index
	events.built.emit(load("res://data/build/palm.tres"))
	_ok(goals.index == index_before, "an off-target action does not advance the goal")

	# --- goal 2: sell -------------------------------------------------------
	events.sold.emit(4)
	_ok(goals.index == index_before, "a partial sale does not finish it (%s)" % goals.line())
	events.sold.emit(6)
	_ok(goals.current().id == "03_till", "reaching 10 coins sold finished it")

	# --- goal 3: plant -----------------------------------------------------
	var centre := Vector2i(land.grid_size / 2, land.grid_size / 2)
	var cell := centre + Vector2i(3, 3)
	farm.till(cell)
	farm.plant(cell, load("res://data/crops/carrot.tres"))
	_ok(goals.current().id == "04_water", "planting advanced the chain")

	# --- goal 4: harvest three --------------------------------------------
	events.crop_harvested.emit(load("res://data/crops/carrot.tres"), 2)
	_ok(goals.current().id == "04_water", "2 of 3 harvested is not done yet")
	events.crop_harvested.emit(load("res://data/crops/carrot.tres"), 1)
	_ok(goals.current().id == "05_rod", "the third finished it")

	# --- goal 5: the rod is a level, not a tally ---------------------------
	game.money = 5000
	game.buy_rod(game.next_rod())
	_ok(goals.current().id == "06_build", "buying the oak rod satisfied 'own tier 1'")

	# --- goal 6: build ------------------------------------------------------
	buildings.place(centre + Vector2i(-6, -6), load("res://data/build/palm.tres"))
	_ok(goals.current().id == "07_deep", "building advanced the chain")

	# --- goal 7, then the end ----------------------------------------------
	game.buy_rod(game.next_rod())
	_ok(goals.done(), "the chain finishes")
	_ok(goals.current() == null and not goals.line().is_empty(),
		"and still says something afterwards: %s" % goals.line())

	# --- survives a save ----------------------------------------------------
	goals.index = 3
	goals.progress = 2
	game.save_game()
	goals.index = 0
	goals.progress = 0
	_ok(game.load_game(), "reloaded")
	_ok(goals.index == 3 and goals.progress == 2,
		"goal position survived the round trip (%d, %d)" % [goals.index, goals.progress])

	quit(failures)
