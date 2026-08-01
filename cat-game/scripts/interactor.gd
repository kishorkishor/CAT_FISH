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
		# Purely cosmetic, but it is the one place the game shows what the cat is
		# actually carrying rather than telling you in a corner of the screen.
		if _player != null:
			_player.holding_rod = tool == Tools.ROD
		Events.tool_changed.emit(tool)

## Set by the touch UI when it takes over. Build placement follows the cursor on
## desktop and the cat's facing on a phone, because a finger has no hover.
var touch_mode := false

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


var _focus: Node2D = null


func _process(_delta: float) -> void:
	if tool == Tools.BUILD:
		_buildings.move_ghost(cursor_cell())
	_update_focus()


## The nearest thing worth talking about, or null. Walking up to something is the
## whole trigger - no aiming, no clicking - because that is the one interaction
## that works identically on a keyboard and on a phone.
func _update_focus() -> void:
	var best: Node2D = null
	var best_distance := INF
	for prop in get_tree().get_nodes_in_group("interactable"):
		var distance: float = prop.reach_from(_player.global_position)
		if distance < prop.interact_range and distance < best_distance:
			best = prop
			best_distance = distance
	if best == _focus:
		return
	if _focus != null and is_instance_valid(_focus):
		_focus.highlight(false)
	_focus = best
	if _focus != null:
		_focus.highlight(true)


func focus() -> Node2D:
	return _focus


## What the HUD should say right now: whatever the cat is stood at wins over the
## tile under its paws, because the thing it walked up to is what it meant.
func prompt() -> String:
	if _focus != null and is_instance_valid(_focus):
		if _focus.hint.is_empty():
			return _focus.label
		return "%s  -  %s" % [_focus.label, _focus.hint]
	return ""


## The cell the cat is standing on, stepped forward by its facing.
func target_cell() -> Vector2i:
	var here := _ground.local_to_map(_ground.to_local(_player.global_position))
	var step: Vector2i = STEP.get(_player.facing(), Vector2i(0, 2))
	return here + step * reach


func cursor_cell() -> Vector2i:
	if touch_mode:
		return target_cell()
	return _ground.local_to_map(_ground.to_local(_ground.get_global_mouse_position()))


## Everything the paw can put into the ground: seed packets and fertiliser. They
## share a cycle because they share a slot - you are stood at a plot deciding
## what to give it, and having to change tool between the two would be busywork.
func seeds() -> Array:
	var out := []
	for id in Game.bag:
		var item: ItemData = Game.items.get(id)
		if item != null and (item.plants != null or item.fertilises):
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
	elif tool == Tools.ROD:
		Tackle.cycle()
		Events.notice.emit("on the hook: %s" % Tackle.name_of())
	elif tool == Tools.HAND:
		seed_index += 1
		var s := current_seed()
		Events.notice.emit(s.display_name if s != null else "no seeds")


func _use() -> void:
	# Something walked up to takes the press before the ground does - otherwise
	# standing at the cottage door with a hoe tills the doorstep.
	if tool != Tools.BUILD and _focus != null and is_instance_valid(_focus) \
			and not _focus.action.is_empty():
		_run(_focus.action)
		return
	match tool:
		Tools.BUILD: _use_build()
		Tools.ROD: pass   # casting owns the rod; see casting.gd
		_: _use_on_ground()


func _run(action: String) -> void:
	match action:
		"sleep": _sleep()
		"shop": _world.get_node("Shop").open()
		"cast": Events.notice.emit("switch to the rod and press use")


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
		_act("build")
		Events.notice.emit("built the %s" % entry.display_name)


func _use_on_ground() -> void:
	var cell := target_cell()
	match tool:
		Tools.HOE:
			if _farm.plots.has(cell):
				if _farm.clear(cell):
					_act("till")
					Events.notice.emit("cleared the plot")
				else:
					Events.notice.emit("something is growing there")
			elif _farm.till(cell):
				_act("till")
				Events.notice.emit("tilled the soil")
			else:
				Events.notice.emit("the hoe needs bare grass")
		Tools.CAN:
			if _farm.water(cell):
				_act("water")
				Events.notice.emit("watered")
			else:
				Events.notice.emit("nothing to water here")
		Tools.AXE:
			var wood: int = _farm.fell(cell)
			if wood > 0:
				_act("till")
				Events.notice.emit("felled it for %d wood" % wood)
			else:
				Events.notice.emit("nothing here to fell")
		Tools.HAND:
			_hand(cell)


## The bare paw does two jobs: it picks ripe crops, and it sows seed into empty
## soil. One button, and which one it means is never ambiguous - a plot either
## has something ready or it does not.
## Only a *successful* use animates. Swinging at nothing sells the idea that
## something happened, which is worse than the cat standing still and the HUD
## saying why it did not.
func _act(action: String) -> void:
	if _player != null:
		_player.play_action(action)


func _hand(cell: Vector2i) -> void:
	var picked: int = _farm.harvest(cell)
	if picked > 0:
		_act("harvest")
		return
	var plot = _farm.plots.get(cell)
	if plot == null:
		Events.notice.emit("till the ground first")
		return
	var item := current_seed()
	if item == null:
		Events.notice.emit("no seeds - buy some at the shop")
		return

	# Fertiliser goes in whether or not something is growing there already, which
	# is the point of feeding a plot that regrows.
	if item.fertilises:
		if not _farm.fertilise(cell):
			Events.notice.emit("that soil is already fed")
			return
		if not Game.take_item(item.id, 1):
			return
		_act("plant")
		Events.notice.emit("fed the soil")
		return

	if plot.crop != null:
		Events.notice.emit("still growing")
		return
	if not Game.take_item(item.id, 1):
		return
	_farm.plant(cell, item.plants)
	_act("plant")
	Events.notice.emit("planted %s" % item.display_name)


## Sleeping only works at a cottage, which gives the buildings a job beyond
## scenery. The cottage declares itself with action = "sleep"; nothing here
## needs to know what a house is called.
func _sleep() -> void:
	if _focus == null or not is_instance_valid(_focus) or _focus.action != "sleep":
		Events.notice.emit("no bed nearby")
		return
	Clock.sleep_until_morning()
	Events.slept.emit()
	Game.save_game()
	Events.notice.emit("slept until morning - day %d" % Clock.day)
