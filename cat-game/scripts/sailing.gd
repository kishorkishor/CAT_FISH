extends Node2D
## Getting on and off the boat.
##
## Owns the swap so neither the cat nor the boat has to know about the other:
## it moves the camera, hides whichever body is not being driven, and refuses a
## landing that would leave the cat standing in the sea.

## How close the cat has to be to climb aboard, in flattened pixels.
@export var board_range := 56.0
## How far out to look for dry land when stepping off.
@export var landing_search := 6

@onready var _world: Node2D = get_parent()
@onready var _water: TileMapLayer = _world.get_node("Water")
@onready var _player: CharacterBody2D = _world.get_node("Entities/Player")
@onready var _boat: CharacterBody2D = _world.get_node("Entities/Boat")
@onready var _interactor: Node2D = _world.get_node("Interactor")

var sailing: bool:
	get: return _boat != null and _boat.aboard


## Whichever body the player is currently driving. Everything that used to reach
## straight for the cat - where a tool lands, where a line goes out - asks this
## instead, so being at sea is one question answered in one place.
func body() -> Node2D:
	return _boat if sailing else _player


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("board"):
		return
	if sailing:
		_step_off()
	else:
		_climb_aboard()


## The boat has to be within arm's reach, measured flattened like every other
## reach test in the game.
func can_board() -> bool:
	if sailing:
		return false
	var d := _boat.global_position - _player.global_position
	return Vector2(d.x, d.y * 2.0).length() <= board_range


func _climb_aboard() -> void:
	if not can_board():
		Events.notice.emit("no boat within reach")
		return
	_move_camera_to(_boat)
	_player.visible = false
	_player.set_physics_process(false)
	_player.locked = true
	_boat.board()
	# The rod is the one tool that still works at sea; the rest need ground.
	_interactor.at_sea = true
	Events.notice.emit("cast off - press F to come ashore")


func _step_off() -> void:
	var spot := _landing_near(_water.local_to_map(_water.to_local(_boat.global_position)))
	if spot.x < 0:
		Events.notice.emit("no shore close enough to step onto")
		return
	_boat.disembark()
	_player.global_position = _water.to_global(_water.map_to_local(spot))
	_player.visible = true
	_player.set_physics_process(true)
	_player.locked = false
	_move_camera_to(_player)
	_interactor.at_sea = false
	Events.notice.emit("ashore")


## Nearest dry land, searched outward. Refusing to land rather than dumping the
## cat in the water is the whole reason this is a search and not an offset.
func _landing_near(from: Vector2i) -> Vector2i:
	for radius in range(1, landing_search + 1):
		for dy in range(-radius * 2, radius * 2 + 1):
			for dx in range(-radius, radius + 1):
				var cell := from + Vector2i(dx, dy)
				if int(_water.depth_at(cell)) == 0:
					return cell
	return Vector2i(-1, -1)


## One camera, moved between the bodies. Two cameras would race for the viewport
## and which one won would depend on tree order.
func _move_camera_to(body: Node2D) -> void:
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam == null:
		cam = _boat.get_node_or_null("Camera2D")
	if cam == null:
		return
	var keep := cam.global_position
	cam.get_parent().remove_child(cam)
	body.add_child(cam)
	cam.owner = null
	cam.position = Vector2.ZERO
	cam.global_position = keep
	cam.make_current()
