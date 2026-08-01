extends SceneTree
## Farming is bounded to marked-out ground: inside a field the tools work,
## outside they refuse and say why.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var fields: Node2D = world.get_node("Fields")
	var farm: Node2D = world.get_node("Farm")
	var water: TileMapLayer = world.get_node("Water")
	var game := root.get_node("Game")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)

	# --- a new game starts with one field, so the mechanic is shown first ------
	_ok(fields.fields.size() >= 1, "a new game starts with a field marked out")
	var starter: Rect2i = fields.fields[0]
	var inside := starter.position + starter.size / 2
	_ok(fields.contains(inside), "and its middle is inside it")

	# --- the field is the gate -----------------------------------------------
	_ok(farm.can_till(inside), "the hoe works inside the field")
	var outside := centre + Vector2i(14, 0)
	_ok(not fields.contains(outside), "there is grass outside it")
	_ok(not farm.can_till(outside), "and the hoe refuses out there")
	_ok(not farm.till(outside), "tilling off-field really does nothing")

	# ...and says why, rather than going quiet.
	var says: String = farm.action_at(outside, Tools.HOE)
	_ok(says.contains("field"), "the prompt explains: '%s'" % says)

	# --- marking new ground ---------------------------------------------------
	var a := centre + Vector2i(12, -6)
	var b := centre + Vector2i(15, 0)
	var rect: Rect2i = fields.between(a, b)
	_ok(rect.size.x == 4 and rect.size.y == 7,
		"two corners make a %dx%d rectangle" % [rect.size.x, rect.size.y])

	game.money = 0
	_ok(not fields.can_mark(rect), "cannot mark ground with no coins")
	_ok(fields.why_not(rect).contains("coins"), "and says so: '%s'" % fields.why_not(rect))

	game.money = 9999
	var price: int = fields.cost_of(rect)
	_ok(price == rect.get_area() * fields.cost_per_cell,
		"priced by the cell: %d cells, %d coins" % [rect.get_area(), price])
	var before: int = game.money
	_ok(fields.mark(rect), "marked it out")
	_ok(game.money == before - price, "and it charged %d" % price)
	_ok(fields.contains(a) and fields.contains(b), "both corners are now field")
	_ok(farm.can_till(a), "so the hoe works there now")

	# --- growing one merges rather than stacking ------------------------------
	var count_before: int = fields.fields.size()
	var grow: Rect2i = fields.between(b, b + Vector2i(2, 2))
	fields.mark(grow)
	_ok(fields.fields.size() == count_before,
		"growing an existing field kept it as one field, not two")

	# Ground already marked must not be charged for twice.
	var overlap: Rect2i = fields.between(a, a + Vector2i(1, 1))
	_ok(fields.cost_of(overlap) == 0, "re-marking ground you own is free")
	_ok(fields.why_not(overlap).contains("already"),
		"and it says so: '%s'" % fields.why_not(overlap))

	# --- a field cannot be marked over water ----------------------------------
	var sea := centre
	for step in range(1, water.grid_size / 2):
		if int(water.depth_at(centre + Vector2i(step, 0))) >= 2:
			sea = centre + Vector2i(step, 0)
			break
	_ok(not fields.can_mark(Rect2i(sea, Vector2i(2, 2))), "cannot mark out the sea")

	# --- giving it back --------------------------------------------------------
	farm.till(a)
	farm.plant(a, load("res://data/crops/carrot.tres"))
	_ok(farm.plots.has(a), "planted something on it")
	_ok(fields.clear_at(a), "gave the field back")
	_ok(not fields.contains(a), "the ground is grass again")
	_ok(not farm.plots.has(a), "and what was growing on it went with it")

	quit(failures)
