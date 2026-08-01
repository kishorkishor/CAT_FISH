extends Node2D
## Everything the cat has put down, and the mode for putting more down.
##
## A placed building is just an instanced prop scene plus the catalogue entry it
## came from, so anything already drawn as a prop can be made buildable by adding
## one line to the catalogue - no new scene, no new script.

const CELL_BLOCKED := "something is already there"
const NEED_LAND := "that has to go on dry land"

class Placed:
	var entry: BuildEntry
	var cell: Vector2i
	var node: Node2D

var placed: Array[Placed] = []

## What can be built, in the order it appears in the picker.
@export var catalogue: Array[BuildEntry] = []

var _ghost: Node2D = null
var _ghost_entry: BuildEntry = null

@onready var _ground: TileMapLayer = get_parent().get_node("Water")
@onready var _land: TileMapLayer = get_parent().get_node("Land")
@onready var _farm: Node2D = get_parent().get_node("Farm")


func _ready() -> void:
	y_sort_enabled = true
	Game.register_buildings(self)


# --- the ghost --------------------------------------------------------------

func show_ghost(entry: BuildEntry) -> void:
	clear_ghost()
	if entry == null or entry.scene == null:
		return
	_ghost_entry = entry
	_ghost = entry.scene.instantiate()
	_ghost.modulate = Color(1, 1, 1, 0.55)
	# The ghost must not collide with anything while it follows the cursor.
	for child in _ghost.get_children():
		if child is StaticBody2D:
			child.queue_free()
	add_child(_ghost)


func clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
	_ghost = null
	_ghost_entry = null


func move_ghost(cell: Vector2i) -> void:
	if _ghost == null:
		return
	_ghost.position = to_local(_ground.to_global(_ground.map_to_local(cell)))
	_ghost.modulate = Color(0.6, 1.0, 0.6, 0.6) if can_place(cell, _ghost_entry) \
		else Color(1.0, 0.5, 0.5, 0.6)


# --- placing ----------------------------------------------------------------

func why_not(cell: Vector2i, entry: BuildEntry) -> String:
	if entry == null:
		return "nothing selected"
	for offset in entry.cells():
		var c := cell + offset
		if not entry.on_water and (_ground.is_fully_secondary(c) or _land._corner_mask(c.x, c.y) != 15):
			return NEED_LAND
		if entry.on_water and not _ground.is_fully_secondary(c):
			return "that has to go on the water"
		if _farm.plots.has(c):
			return CELL_BLOCKED
		for p in placed:
			for taken in p.entry.cells():
				if p.cell + taken == c:
					return CELL_BLOCKED
	if Game.money < entry.cost:
		return "costs %d coins" % entry.cost
	return ""


func can_place(cell: Vector2i, entry: BuildEntry) -> bool:
	return why_not(cell, entry).is_empty()


func place(cell: Vector2i, entry: BuildEntry, charge := true) -> bool:
	if charge and not can_place(cell, entry):
		return false
	if charge and not Game.spend(entry.cost):
		return false
	var p := Placed.new()
	p.entry = entry
	p.cell = cell
	p.node = entry.scene.instantiate()
	p.node.position = to_local(_ground.to_global(_ground.map_to_local(cell)))
	add_child(p.node)
	placed.append(p)
	if charge:
		Events.built.emit(entry)
	return true


## Takes back the building under a cell and refunds part of its cost.
func demolish(cell: Vector2i) -> bool:
	for i in range(placed.size() - 1, -1, -1):
		var p := placed[i]
		for offset in p.entry.cells():
			if p.cell + offset == cell:
				Game.earn(int(p.entry.cost * p.entry.refund))
				p.node.queue_free()
				placed.remove_at(i)
				return true
	return false


# --- saving -----------------------------------------------------------------

func to_save() -> Array:
	var out := []
	for p in placed:
		out.append({"entry": p.entry.resource_path, "x": p.cell.x, "y": p.cell.y})
	return out


func from_save(data: Array) -> void:
	for p in placed:
		p.node.queue_free()
	placed.clear()
	for row in data:
		var path: String = row.get("entry", "")
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		place(Vector2i(int(row.get("x", 0)), int(row.get("y", 0))), load(path), false)
