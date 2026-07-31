extends Node
## The fish log: every species seen, how many, and the best one.
##
## This is the meta-loop the design has always pointed at - the reason to keep
## casting once the coins stop mattering. Money is spent; a filled log is not.
##
## Size is rolled per catch rather than stored on the fish, so "a big one" is a
## story about a particular afternoon instead of a property of the species.

signal recorded(fish: FishData, size: float, is_record: bool)

## species id -> {"count": int, "best": float, "day": int}
var entries: Dictionary = {}


func _ready() -> void:
	Events.fish_caught.connect(_record)


## Sizes cluster near the middle and thin out at both ends, so a record feels
## earned rather than handed over every third fish.
func roll_size(fish: FishData) -> float:
	var base := 0.5 * (randf() + randf())
	var spread := 0.55 + float(fish.rarity) * 0.12
	return snappedf(fish.value * (0.6 + base * spread) + 4.0, 0.1)


func _record(fish: FishData) -> void:
	if fish.item == null:
		return
	var id: String = fish.item.id
	var size := roll_size(fish)
	var entry: Dictionary = entries.get(id, {"count": 0, "best": 0.0, "day": 0})
	entry["count"] = int(entry["count"]) + 1
	var is_record: bool = size > float(entry["best"])
	if is_record:
		entry["best"] = size
		entry["day"] = Clock.day
	entries[id] = entry
	recorded.emit(fish, size, is_record)
	if is_record and int(entry["count"]) > 1:
		Events.notice.emit("a record %s - %.1fcm" % [fish.display_name, size])


func seen(id: String) -> bool:
	return entries.has(id)


func caught_count() -> int:
	return entries.size()


## Every species in the game, so the log can show the gaps as well as the fills.
func all_species() -> Array:
	var out := []
	var dir := DirAccess.open("res://data/fish")
	if dir == null:
		return out
	var names := dir.get_files()
	names.sort()
	for file in names:
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			var fish: FishData = load("res://data/fish/%s" % file.trim_suffix(".remap"))
			if fish != null:
				out.append(fish)
	out.sort_custom(func(a, b): return a.value < b.value)
	return out


func to_save() -> Dictionary:
	return entries


func from_save(data: Dictionary) -> void:
	entries.clear()
	for id in data:
		var row: Dictionary = data[id]
		entries[id] = {
			"count": int(row.get("count", 0)),
			"best": float(row.get("best", 0.0)),
			"day": int(row.get("day", 0)),
		}
