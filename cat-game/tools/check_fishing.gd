extends SceneTree
## Runs the whole fishing loop twice, headless: once letting the fish escape,
## once reeling it in bang-bang, and checks the signals and cleanup both ways.

var _caught := 0
var _escaped := 0
var _caught_id := ""


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	# A CLI script compiles before the autoloads register, so the Events global
	# is not visible here at compile time - fetch the node instead.
	var events := root.get_node("Events")
	events.fish_caught.connect(func(f):
		_caught += 1
		_caught_id = f.item.id if f.item != null else "")
	events.fish_escaped.connect(func(): _escaped += 1)

	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")
	var casting: Node2D = world.get_node("Casting")
	casting.wait_min = 0.1
	casting.wait_max = 0.2
	var failures := 0

	# Stand a little inland of the south shore, facing south (the default), so
	# the cast scan finds water ahead.
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var shore := -1
	for j in range(1, water.grid_size / 2):
		if water.is_fully_secondary(centre + Vector2i(0, j)):
			shore = j
			break
	player.global_position = water.map_to_local(centre + Vector2i(0, shore - 3))
	await physics_frame

	# --- Round 1: let it escape -------------------------------------------
	# The rod is a tool now, so casting is "use" while it is the one in paw.
	var interactor: Node2D = world.get_node("Interactor")
	interactor.tool = Tools.ROD
	var ev := InputEventAction.new()
	ev.action = "use"
	ev.pressed = true
	casting._unhandled_input(ev)
	var minigame: CanvasLayer = await _await_minigame(casting)
	if minigame == null:
		print("FAIL minigame never opened")
		quit(1)
		return
	if not player.locked:
		print("FAIL player not locked during the fight")
		failures += 1
	var waited := 0.0
	while _escaped == 0 and waited < 8.0:
		await physics_frame
		waited += 1.0 / 60.0
	if _escaped == 1 and _caught == 0:
		print("ok   slack line -> fish escaped after %.1fs" % waited)
	else:
		print("FAIL escape path: caught=%d escaped=%d" % [_caught, _escaped])
		failures += 1
	await physics_frame
	if player.locked or casting._busy:
		print("FAIL not cleaned up after escape")
		failures += 1

	# --- Round 2: reel it in ----------------------------------------------
	casting._unhandled_input(ev)
	minigame = await _await_minigame(casting)
	if minigame == null:
		print("FAIL second minigame never opened")
		quit(1)
		return
	waited = 0.0
	while _caught == 0 and _escaped < 2 and waited < 40.0:
		# Bang-bang: hold whenever tension sits below the band centre.
		if is_instance_valid(minigame) and minigame._tension < minigame._band_centre:
			Input.action_press("reel")
		else:
			Input.action_release("reel")
		await physics_frame
		waited += 1.0 / 60.0
	Input.action_release("reel")
	if _caught == 1:
		print("ok   bang-bang reeling -> caught after %.1fs" % waited)
	else:
		print("FAIL catch path: caught=%d escaped=%d after %.1fs" % [_caught, _escaped, waited])
		failures += 1
	await physics_frame
	if player.locked or casting._busy:
		print("FAIL not cleaned up after catch")
		failures += 1

	# --- The loop closes: bag fills, selling turns it into coins -----------
	var game := root.get_node("Game")
	if not _caught_id.is_empty() and game.count_of(_caught_id) == 1:
		print("ok   the %s landed in the bag (worth %d)" % [_caught_id, game.bag_value()])
	else:
		print("FAIL catch not in the bag: id=%s count=%d" % [_caught_id, game.count_of(_caught_id)])
		failures += 1
	# The cat starts with seeds, so selling clears the catch and leaves the seeds.
	var seeds_before: int = game.count_of("carrot_seed")
	game.sell_all()
	if game.money > 0 and game.count_of(_caught_id) == 0:
		print("ok   sold the catch for %d coins" % game.money)
	else:
		print("FAIL sell: money=%d still holding %d" % [game.money, game.count_of(_caught_id)])
		failures += 1
	if game.count_of("carrot_seed") == seeds_before:
		print("ok   selling kept the seeds")
	else:
		print("FAIL selling ate the seeds")
		failures += 1

	quit(failures)


func _await_minigame(casting: Node2D) -> CanvasLayer:
	var waited := 0.0
	while waited < 3.0:
		for child in casting.get_children():
			if child is CanvasLayer:
				return child
		await physics_frame
		waited += 1.0 / 60.0
	return null
