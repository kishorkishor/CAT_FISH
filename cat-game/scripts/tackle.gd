extends Node
## What is on the hook. Kept apart from the bag so the rest of the game does not
## have to know that some items are consumed by casting.

signal changed(bait: BaitData)

## null means a bare hook, which is always allowed and always works.
var bait: BaitData = null
var all: Array[BaitData] = []


func _ready() -> void:
	var dir := DirAccess.open("res://data/bait")
	if dir == null:
		return
	var names := dir.get_files()
	names.sort()
	for file in names:
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			var data: BaitData = load("res://data/bait/%s" % file.trim_suffix(".remap"))
			if data != null:
				all.append(data)
	all.sort_custom(func(a, b): return a.richness < b.richness)


func name_of() -> String:
	return bait.display_name if bait != null else "bare hook"


## Step to the next bait the cat actually has, wrapping through the bare hook, so
## running out never leaves the game in a state you cannot cast from.
func cycle() -> void:
	var held: Array[BaitData] = [null]
	for candidate in all:
		if Game.count_of(candidate.id) > 0:
			held.append(candidate)
	var index := held.find(bait)
	bait = held[(index + 1) % held.size()]
	changed.emit(bait)


## Called once per cast. Returns what was on the hook, having spent it.
func consume() -> BaitData:
	if bait == null:
		return null
	var used := bait
	if not Game.take_item(bait.id, 1):
		bait = null
		changed.emit(bait)
		return null
	if Game.count_of(bait.id) <= 0:
		bait = null
		changed.emit(bait)
	return used


func richness_of(used: BaitData) -> float:
	return used.richness if used != null else 0.0


func depth_bonus_of(used: BaitData) -> int:
	return used.depth_bonus if used != null else 0
