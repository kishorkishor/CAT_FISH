extends Node2D
## What happens when the cat uses what it is holding.
##
## Every tool acts on the *cell the cat is facing*, not on the mouse. That keeps
## one code path for keyboard now and touch later, and it means the cat can never
## till a plot on the far side of the island by clicking there.
##
## Building is the exception: a building is placed under the cursor, because
## picking a spot for a house is a decision you make by looking around.

## How many cells ahead the cat reaches.
@export var reach := 1
## Seeds and tools the cat starts the game with.
@export var starting_seeds: Array[ItemData] = []

var tool: int = Tools.HAND:
	set(value):
		tool = value
		_buildings.clear_ghost()
		if tool == Tools.BUILD:
			_buildings.show_ghost(current_build())
		Events.tool_changed.emit(tool)

var seed_index := 0
var build_index := 0

@onready var _world: Node2D = get_parent()
@onready var _ground: TileMapLayer = _world.get_node("Water")
@onready var _player: CharacterBody2D = _world.get_node("Entities/Player")
@onready var _farm: Node2D = _world.get_node("Farm")
@onready var _buildings: Node2D = _world.get_node("Buildings")

## Facing to a cell step. The vertical step is doubled because a cell is twice as
## wide as it is tall, so one step north is two rows up.
const STEP := {
	"south": Vector2i(0, 2), "north": Vector2i(0, -2),
	"east": Vector2i(1, 0), "west": Vector2i(-1, 0),
	"south-east": Vector2i(1, 1), "north-west": Vector2i(-1, -1),
	"south-west": Vector2i(-1, 1), "north-east": Vector2i(1, -1),
}


func _ready() -> void:
	for item in starting_seeds:
		if item != null:
			Game.add_item(item.id, 5)


func _process(_delta: float) -> void:
	if tool == Tools.BUILD:
		_buildings.move_ghost(cursor_cell())


## The cell the cat is standing on, stepped forward by its facing.
func target_cell() -> Vector2i:
	var here := _ground.local_to_map(_ground.to_local(_player.global_position))
	var step: Vector2i = STEP.get(_player.facing(), Vector2i(0, 2))
	return here + step * reach


func cursor_cell() -> Vector2i:
	return _ground.local_to_map(_ground.to_local(_ground.get_global_mouse_position()))


func seeds() -> Array:
	var out := []
	for id in Game.bag:
		var item: ItemData = Game.items.get(id)
		if item != null and item.plants != null:
			out.append(item)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


func current_seed() -> ItemData:
	var list := seeds()
	if list.is_empty():
		return null
	return list[seed_index % list.size()]


func current_build() -> BuildEntry:
	if _buildings.catalogue.is_empty():
		return null
	return _buildings.catalogue[build_index % _buildings.catalogue.size()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_next"):
		tool = (tool + 1) % Tools.NAMES.size()
	elif event.is_action_pressed("tool_prev"):
		tool = (tool - 1 + Tools.NAMES.size()) % Tools.NAMES.size()
	elif event.is_action_pressed("cycle"):
		_cycle()
	elif event.is_action_pressed("use"):
		_use()
	elif event.is_action_pressed("sleep"):
		_sleep()
	elif event.is_action_pressed("save_game"):
		Game.save_game()
		Events.notice.emit("saved")


## The same key steps through whatever the current tool has a list of.
func _cycle() -> void:
	if tool == Tools.BUILD:
		build_index += 1
		_buildings.show_ghost(current_build())
		Events.notice.emit(current_build().display_name if current_build() else "nothing to build")
	elif tool == Tools.HAND:
		seed_index += 1
		var s := current_seed()
		Events.notice.emit(s.display_name if s != null else "no seeds")


func _use() -> void:
	match tool:
		Tools.BUILD: _use_build()
		Tools.ROD: pass   # casting owns the rod; see casting.gd
		_: _use_on_ground()


func _use_build() -> void:
	var cell := cursor_cell()
	var entry := current_build()
	if Input.is_action_pressed("modify"):
		if not _buildings.demolish(cell):
			Events.notice.emit("nothing to take down there")
		return
	var reason: String = _buildings.why_not(cell, entry)
	if not reason.is_empty():
		Events.notice.emit(reason)
		return
	if _buildings.place(cell, entry):
		Events.notice.emit("built the %s" % entry.display_name)


func _use_on_ground() -> void:
	var cell := target_cell()
	match tool:
		Tools.HOE:
			if _farm.plots.has(cell):
				if _farm.clear(cell):
					Events.notice.emit("cleared the plot")
				else:
					Events.notice.emit("something is growing there")
			elif _farm.till(cell):
				Events.notice.emit("tilled the soil")
			else:
				Events.notice.emit("the hoe needs bare grass")
		Tools.CAN:
			if _farm.water(cell):
				Events.notice.emit("watered")
			else:
				Events.notice.emit("nothing to water here")
		Tools.HAND:
			_hand(cell)


## The bare paw does two jobs: it picks ripe crops, and it sows seed into empty
## soil. One button, and which one it means is never ambiguous - a plot either
## has something ready or it does not.
func _hand(cell: Vector2i) -> void:
	var picked: int = _farm.harvest(cell)
	if picked > 0:
		return
	var plot = _farm.plots.get(cell)
	if plot == null:
		Events.notice.emit("till the ground first")
		return
	if plot.crop != null:
		Events.notice.emit("still growing")
		return
	var item := current_seed()
	if item == null:
		Events.notice.emit("no seeds - buy some at the shop")
		return
	if not Game.take_item(item.id, 1):
		return
	_farm.plant(cell, item.plants)
	Events.notice.emit("planted %s" % item.display_name)


## Sleeping only works indoors, which gives the cottage a job beyond scenery.
func _sleep() -> void:
	var near_bed := false
	for node in _world.get_node("Entities").get_children():
		if node.name.begins_with("House") \
				and node.global_position.distance_to(_player.global_position) < 90.0:
			near_bed = true
	if not near_bed:
		Events.notice.emit("no bed nearby")
		return
	Clock.sleep_until_morning()
	Game.save_game()
	Events.notice.emit("slept until morning")
