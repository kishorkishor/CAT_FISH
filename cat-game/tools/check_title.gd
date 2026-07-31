extends SceneTree
## Boots the title screen and checks both doors: continue restores a save, new
## voyage does not inherit one.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _initialize() -> void:
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")

	# --- no save: continue is not offered ----------------------------------
	game.wipe()
	var title := (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await process_frame
	_ok(title.get_node("%Continue").disabled, "with no save, continue is greyed out")
	_ok(not title.get_node("%NewGame").disabled, "new voyage is always available")
	title.free()

	# --- lay down a save ---------------------------------------------------
	game.money = 412
	game.add_item("tuna", 3)
	clock.day = 9
	game.save_game()

	title = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await process_frame
	_ok(not title.get_node("%Continue").disabled, "with a save, continue is offered")
	var line: String = title.get_node("%SavedLine").text
	_ok(line.contains("day 9") and line.contains("412"),
		"and it says what would be resumed: %s" % line)

	# --- continue asks the world to resume ---------------------------------
	game.money = 0
	title._enter(true)
	_ok(game.resume_on_load, "continue flags the world to load the save")
	title.free()

	# --- the world honours it ----------------------------------------------
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	_ok(game.money == 412, "the world loaded the save (%d coins)" % game.money)
	_ok(clock.day == 9, "on day %d" % clock.day)
	_ok(not game.resume_on_load, "and the flag was cleared so it does not reload")
	world.free()

	# --- new voyage starts blank -------------------------------------------
	title = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await process_frame
	title._enter(false)
	_ok(game.money == 0 and game.count_of("tuna") == 0, "new voyage empties the bag and purse")
	_ok(clock.day == 1, "and puts the calendar back to day 1")
	_ok(not FileAccess.file_exists(game.SAVE_PATH), "the old save file is gone")
	_ok(game.rod.id == "bamboo", "back to the bamboo rod")

	quit(failures)
