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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cast") and not _busy and not _player.in_water:
		var cell := _find_water_ahead()
		if cell.x >= 0:
			_cast_to(cell)


func _find_water_ahead() -> Vector2i:
	var start := _water.local_to_map(_water.to_local(_player.global_position))
	var step: Vector2i = CELL_STEP.get(_player.facing(), Vector2i(0, 2))
	for i in range(1, cast_range + 1):
		var cell := start + step * i
		if _water.is_fully_secondary(cell):
			return cell
	return Vector2i(-1, -1)


func _cast_to(cell: Vector2i) -> void:
	_busy = true
	_player.locked = true
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
	minigame.caught.connect(func(_fish): _finish())
	minigame.escaped.connect(_finish)
	minigame.start(_pick_fish())


func _pick_fish() -> FishData:
	if fish_pool.is_empty():
		push_error("casting has no fish_pool")
		return FishData.new()
	# Squaring the roll biases towards index 0, so the head of the list is the
	# common catch without a separate weight table yet.
	var roll := _rng.randf()
	return fish_pool[int(roll * roll * fish_pool.size())]


func _finish() -> void:
	if is_instance_valid(_bobber):
		_bobber.queue_free()
	_player.locked = false
	_busy = false
