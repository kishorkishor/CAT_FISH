extends SceneTree
## Bait is a real decision: it is spent, it biases the roll, and running out
## never leaves the rod unusable.
var failures := 0
func _ok(p: bool, m: String) -> void:
	print(("ok   " if p else "FAIL ") + m)
	if not p: failures += 1

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var game := root.get_node("Game")
	var tackle := root.get_node("Tackle")
	var casting: Node2D = world.get_node("Casting")
	var weather := root.get_node("Weather")
	weather.kind = weather.Kind.CLEAR

	_ok(tackle.all.size() == 3, "%d baits in the box" % tackle.all.size())
	_ok(tackle.bait == null and tackle.name_of() == "bare hook", "starts on a bare hook")

	# --- cycling only offers what is actually held --------------------------
	tackle.cycle()
	_ok(tackle.bait == null, "with an empty bag, cycling stays on the bare hook")

	game.add_item("worm_bait", 2)
	tackle.cycle()
	_ok(tackle.bait != null and tackle.bait.id == "worm_bait", "with worms held, cycling picks them up")

	# --- casting spends it ---------------------------------------------------
	var before: int = game.count_of("worm_bait")
	var used = tackle.consume()
	_ok(used != null and used.id == "worm_bait", "casting takes the bait off the hook")
	_ok(game.count_of("worm_bait") == before - 1, "and out of the bag (%d left)" % game.count_of("worm_bait"))

	tackle.consume()
	_ok(tackle.bait == null, "running out drops back to a bare hook rather than jamming")
	_ok(tackle.consume() == null, "and a bare hook can still be cast")

	# --- richness straightens the odds --------------------------------------
	var plain_total := 0
	var rich_total := 0
	for i in 400:
		plain_total += casting._pick_fish(3, 0.0).value
		rich_total += casting._pick_fish(3, 0.9).value
	_ok(rich_total > plain_total * 1.4,
		"rich bait lands better fish (%d vs %d over 400 casts)" % [rich_total, plain_total])

	# --- a lure reaches deeper ------------------------------------------------
	var lure: BaitData = load("res://data/bait/lure_bait.tres")
	_ok(tackle.depth_bonus_of(lure) == 1, "the lure reaches one band deeper")
	_ok(tackle.depth_bonus_of(null) == 0, "a bare hook does not")

	# --- and it is buyable -----------------------------------------------------
	var shop_item: ItemData = game.items.get("shrimp_bait")
	_ok(shop_item != null and shop_item.price > 0, "bait is stocked at the stall (%d coins)" % shop_item.price)
	quit(failures)
