extends SceneTree
## The fish log: records species, tracks a personal best, shows the gaps, saves.
var failures := 0
func _ok(p: bool, m: String) -> void:
	print(("ok   " if p else "FAIL ") + m)
	if not p: failures += 1

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var game := root.get_node("Game")
	var events := root.get_node("Events")
	var log_book := root.get_node("LogBook")
	log_book.entries.clear()

	var species: Array = log_book.all_species()
	_ok(species.size() >= 5, "%d species in the log" % species.size())
	var depths := {}
	for f in species:
		depths[f.min_depth] = int(depths.get(f.min_depth, 0)) + 1
	_ok(depths.has(1) and depths.has(2) and depths.has(3),
		"species spread across every depth: %s" % [depths])
	_ok(log_book.caught_count() == 0, "the log starts empty")

	var sardine: FishData = load("res://data/fish/sardine.tres")
	_ok(not log_book.seen("sardine"), "an uncaught fish is unseen")
	events.fish_caught.emit(sardine)
	_ok(log_book.seen("sardine"), "catching one records it")
	_ok(log_book.caught_count() == 1, "and only it")
	_ok(int(log_book.entries["sardine"]["count"]) == 1, "count is 1")
	var first: float = log_book.entries["sardine"]["best"]
	_ok(first > 0.0, "a size was rolled (%.1fcm)" % first)

	for i in 30:
		events.fish_caught.emit(sardine)
	_ok(int(log_book.entries["sardine"]["count"]) == 31, "31 caught")
	_ok(float(log_book.entries["sardine"]["best"]) >= first, "the best only ever goes up")

	# a bigger species should roll bigger fish
	var tuna: FishData = load("res://data/fish/tuna.tres")
	var tuna_total := 0.0
	var sardine_total := 0.0
	for i in 40:
		tuna_total += log_book.roll_size(tuna)
		sardine_total += log_book.roll_size(sardine)
	_ok(tuna_total > sardine_total * 3.0,
		"tuna roll far larger than sardines (%.0f vs %.0f over 40)" % [tuna_total, sardine_total])

	game.save_game()
	log_book.entries.clear()
	_ok(game.load_game(), "reloaded")
	_ok(log_book.seen("sardine") and int(log_book.entries["sardine"]["count"]) == 31,
		"the log survived the round trip")

	game.wipe()
	_ok(log_book.caught_count() == 0, "a new voyage clears the log")
	quit(failures)
