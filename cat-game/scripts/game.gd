extends Node
## Run state: the bag, the money, the save file. Listens to the bus rather than
## being called, so nothing needs a reference to it to add a catch or a harvest.

const SAVE_PATH := "user://catamaran.save"
## Bumped whenever the shape of the save changes. An older file is discarded
## rather than half-read, which is the one failure mode worth being strict about.
const SAVE_VERSION := 1

var money := 0
## item id -> count.
var bag: Dictionary = {}
## The rod in paw. Set from the catalogue at boot, then bought upwards.
var rod: RodData = null
## Every rod in the game, lowest tier first.
var rods: Array[RodData] = []

## Every item in the game, by id. Filled from res://data/items at boot so the
## save file can store ids instead of resource paths.
var items: Dictionary = {}

## Set by the title screen. The world reads it once on boot and then forgets.
var resume_on_load := false

var _farm: Node = null
var _buildings: Node = null


func _ready() -> void:
	_load_catalogue()
	Events.fish_caught.connect(func(fish: FishData):
		if fish.item != null:
			add_item(fish.item.id, 1))


func _load_catalogue() -> void:
	for path in _tres_under("res://data/items"):
		var item: ItemData = load(path)
		if item != null and not item.id.is_empty():
			items[item.id] = item
	for path in _tres_under("res://data/rods"):
		var r: RodData = load(path)
		if r != null:
			rods.append(r)
	rods.sort_custom(func(a, b): return a.tier < b.tier)
	if rod == null and not rods.is_empty():
		rod = rods[0]


## The next rung up, or null at the top. The shop never shows a rod two tiers
## away: the ladder is meant to be climbed, not skipped.
func next_rod() -> RodData:
	for r in rods:
		if r.tier == rod.tier + 1:
			return r
	return null


func buy_rod(r: RodData) -> bool:
	if r == null or r.tier != rod.tier + 1 or not spend(r.price):
		return false
	rod = r
	Events.rod_changed.emit(rod)
	return true


func sellable_count() -> int:
	var n := 0
	for id in bag:
		var item: ItemData = items.get(id)
		if item != null and item.plants == null:
			n += bag[id]
	return n


func _tres_under(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file in dir.get_files():
		# Exported projects rename .tres to .remap, so match on the stem.
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			out.append("%s/%s" % [dir_path, file.trim_suffix(".remap")])
	return out


# --- the bag ---------------------------------------------------------------

func add_item(id: String, count := 1) -> void:
	if count <= 0:
		return
	bag[id] = bag.get(id, 0) + count
	Events.bag_changed.emit()


func take_item(id: String, count := 1) -> bool:
	if bag.get(id, 0) < count:
		return false
	bag[id] -= count
	if bag[id] <= 0:
		bag.erase(id)
	Events.bag_changed.emit()
	return true


func count_of(id: String) -> int:
	return bag.get(id, 0)


func total_items() -> int:
	var n := 0
	for count in bag.values():
		n += count
	return n


# --- money -----------------------------------------------------------------

func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	Events.money_changed.emit(money)
	return true


func earn(amount: int) -> void:
	money += amount
	Events.money_changed.emit(money)


## Sells everything that is not a seed. Seeds are excluded on purpose: selling
## the packet you just bought by hitting one button is a bad surprise.
func sell_all() -> int:
	var total := 0
	for id in bag.keys():
		var item: ItemData = items.get(id)
		if item == null or item.plants != null:
			continue
		total += item.value * bag[id]
		bag.erase(id)
	if total > 0:
		earn(total)
		Events.sold.emit(total)
		Events.bag_changed.emit()
	return total


func bag_value() -> int:
	var total := 0
	for id in bag:
		var item: ItemData = items.get(id)
		if item != null and item.plants == null:
			total += item.value * bag[id]
	return total


# --- saving ----------------------------------------------------------------

## Back to a blank voyage without restarting the process, so New Game after a
## Continue does not inherit the old bag.
func wipe() -> void:
	money = 0
	bag.clear()
	rod = rods[0] if not rods.is_empty() else null
	Clock.day = 1
	Clock.hour = Clock.MORNING
	Goals.index = 0
	Goals.progress = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Events.money_changed.emit(money)
	Events.bag_changed.emit()


func register_farm(farm: Node) -> void:
	_farm = farm


func register_buildings(buildings: Node) -> void:
	_buildings = buildings


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"bag": bag,
		"day": Clock.day,
		"rod": rod.id if rod != null else "",
		"hour": Clock.hour,
		"farm": _farm.to_save() if _farm != null else [],
		"buildings": _buildings.to_save() if _buildings != null else [],
		"goals": Goals.to_save(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "  "))
	Events.game_saved.emit()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != SAVE_VERSION:
		push_warning("save file is missing or from another version - starting fresh")
		return false

	money = int(parsed.get("money", 0))
	bag.clear()
	for id in parsed.get("bag", {}):
		bag[id] = int(parsed["bag"][id])
	Clock.day = int(parsed.get("day", 1))
	var rod_id: String = parsed.get("rod", "")
	for r in rods:
		if r.id == rod_id:
			rod = r
	Events.rod_changed.emit(rod)
	Clock.hour = float(parsed.get("hour", Clock.MORNING))
	if _farm != null:
		_farm.from_save(parsed.get("farm", []))
	if _buildings != null:
		_buildings.from_save(parsed.get("buildings", []))
	Goals.from_save(parsed.get("goals", {}))

	Events.money_changed.emit(money)
	Events.bag_changed.emit()
	return true
