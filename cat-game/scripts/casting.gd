extends Node2D
## Casting: stand near water, press cast, wait for the bite, fight the fish.
##
## Owns the flow from keypress to minigame and back. The minigame itself knows
## nothing about any of this - it gets a FishData and answers caught or escaped.

## How many cells ahead to look for open water.
@export var cast_range := 6
## Bite wait, seconds.
@export var wait_min := 1.0
@export var wait_max := 4.0
## The fish that can bite here. Weighted towards the front of the list.
@export var fish_pool: Array[FishData] = []

var _bobber: Node2D
var _busy := false
var _rng := RandomNumberGenerator.new()

@onready var _world: Node2D = get_parent()
@onready var _water: TileMapLayer = _world.get_node("Water")
@onready var _player: CharacterBody2D = _world.get_node("Entities/Player")

## Screen facing to a cell step. Rough on purpose - it only aims the scan.
const CELL_STEP := {
	"south": Vector2i(0, 2), "north": Vector2i(0, -2),
	"east": Vector2i(1, 0), "west": Vector2i(-1, 0),
	"south-east": Vector2i(1, 1), "north-west": Vector2i(-1, -1),
	"south-west": Vector2i(-1, 1), "north-east": Vector2i(1, -1),
}


@onready var _interactor: Node2D = _world.get_node("Interactor")


func _unhandled_input(event: InputEvent) -> void:
	# The rod is a tool like any other, so casting is the "use" verb while it is
	# the one in paw. Wading is fine to cast from; swimming is not.
	if not event.is_action_pressed("use") or _busy:
		return
	if _interactor.tool != Tools.ROD or _player.in_water:
		return
	var cell := _find_water_ahead()
	if cell.x >= 0:
		_cast_to(cell)
	else:
		Events.notice.emit("no water within reach of the %s" % Game.rod.display_name)


## The deepest water the rod can reach, looking ahead from the cat. Deliberately
## the *deepest* rather than the nearest: with a good rod you want the line out
## past the shallows, and having to stand in exactly the right spot to get there
## would be fiddly rather than skilful.
func _find_water_ahead() -> Vector2i:
	var start := _water.local_to_map(_water.to_local(_player.global_position))
	var step: Vector2i = CELL_STEP.get(_player.facing(), Vector2i(0, 2))
	var best := Vector2i(-1, -1)
	var best_depth := 0
	for i in range(1, Game.rod.cast_range + 1):
		var cell := start + step * i
		if not _water.is_fully_secondary(cell):
			continue
		var depth: int = _water.depth_at(cell)
		var reach: int = Game.rod.max_depth + Weather.depth_bonus() + Tackle.depth_bonus_of(Tackle.bait)
		if depth <= reach and depth > best_depth:
			best = cell
			best_depth = depth
	return best


func _cast_to(cell: Vector2i) -> void:
	_busy = true
	_player.locked = true
	_player.play_action("cast")
	_bobber = preload("res://scenes/bobber.tscn").instantiate()
	_bobber.position = _water.map_to_local(cell)
	_world.get_node("Entities").add_child(_bobber)

	await get_tree().create_timer(_rng.randf_range(wait_min, wait_max)).timeout
	if not is_instance_valid(_bobber):
		return
	Events.fish_hooked.emit()
	_bobber.bite()

	var minigame := preload("res://scenes/fishing.tscn").instantiate()
	add_child(minigame)
	minigame.caught.connect(func(_fish): _finish(true))
	minigame.escaped.connect(func(): _finish(false))
	# The fight lasts as long as it lasts, so the haul is held rather than timed.
	_player.play_action("reel", true)
	var used := Tackle.consume()
	minigame.start(_pick_fish(_water.depth_at(cell) + Weather.depth_bonus()
		+ Tackle.depth_bonus_of(used), Tackle.richness_of(used)))


## Only fish that live at this depth or shallower will bite, and the rarer ones
## live further out. That single rule is what a new rod actually buys.
func _pick_fish(depth: int, richness := 0.0) -> FishData:
	var here: Array[FishData] = []
	for fish in fish_pool:
		if fish != null and fish.min_depth <= depth:
			here.append(fish)
	if here.is_empty():
		push_error("no fish live at depth %d" % depth)
		return fish_pool[0]
	here.sort_custom(func(a, b): return a.value < b.value)
	# Squaring the roll biases towards the cheap end, so the good fish stay a
	# reward rather than the default. Bait straightens that curve: at full
	# richness the roll is flat and every fish present is equally likely.
	var roll := _rng.randf()
	var biased: float = lerpf(roll * roll, roll, richness)
	return here[mini(int(biased * here.size()), here.size() - 1)]


func _finish(landed := false) -> void:
	if is_instance_valid(_bobber):
		_bobber.queue_free()
	_player.stop_action()
	_player.locked = false
	_busy = false
	if landed:
		_player.play_action("catch")
