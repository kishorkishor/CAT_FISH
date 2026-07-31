extends Node
## Runs the goal chain. Listens to the bus and never asks anything a question,
## so adding a goal is a .tres file and nothing else.

signal changed
signal completed(goal: GoalData)

var chain: Array[GoalData] = []
var index := 0
var progress := 0


func _ready() -> void:
	for path in _chain_paths():
		var goal: GoalData = load(path)
		if goal != null:
			chain.append(goal)
	chain.sort_custom(func(a, b): return a.id < b.id)

	Events.fish_caught.connect(func(_f): _bump("caught", 1))
	Events.crop_planted.connect(func(_c): _bump("planted", 1))
	Events.crop_harvested.connect(func(_c, count): _bump("harvested", count))
	Events.sold.connect(func(amount): _bump("sold", amount))
	Events.built.connect(func(_e): _bump("built", 1))
	Events.slept.connect(func(): _bump("slept", 1))
	Events.rod_changed.connect(func(rod):
		if rod != null:
			_set_to("rod", rod.tier))


func _chain_paths() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open("res://data/goals")
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			out.append("res://data/goals/%s" % file.trim_suffix(".remap"))
	return out


func current() -> GoalData:
	return chain[index] if index < chain.size() else null


func done() -> bool:
	return index >= chain.size()


## Progress counts up. Used by everything except the rod, which is a level rather
## than a tally - buying tier 2 should satisfy "own tier 2" outright.
func _bump(track: String, amount: int) -> void:
	var goal := current()
	if goal == null or goal.track != track:
		return
	progress += amount
	_check(goal)


func _set_to(track: String, value: int) -> void:
	var goal := current()
	if goal == null or goal.track != track:
		return
	progress = maxi(progress, value)
	_check(goal)


func _check(goal: GoalData) -> void:
	if progress < goal.target:
		changed.emit()
		return
	index += 1
	progress = 0
	if goal.reward > 0:
		Game.earn(goal.reward)
	completed.emit(goal)
	Events.notice.emit("done: %s  (+%d coins)" % [goal.title, goal.reward])
	changed.emit()


func line() -> String:
	var goal := current()
	if goal == null:
		return "the island is yours - go fishing"
	if goal.target > 1:
		return "%s  (%d/%d)" % [goal.title, mini(progress, goal.target), goal.target]
	return goal.title


func to_save() -> Dictionary:
	return {"index": index, "progress": progress}


func from_save(data: Dictionary) -> void:
	index = int(data.get("index", 0))
	progress = int(data.get("progress", 0))
	changed.emit()
