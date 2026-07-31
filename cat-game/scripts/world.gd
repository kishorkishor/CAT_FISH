extends Node2D
## An island: grass in the middle, a sand beach, open water around it.
##
## Two 16-tile corner sets stacked. The lower layer paints sand into water; the
## upper paints grass into sand and leaves its empty cells unpainted so the water
## shows through. Neither set knows about the other - the illusion of three
## terrains comes from the stacking, not from a bigger tileset.

@onready var _water: TileMapLayer = $Water
@onready var _land: TileMapLayer = $Land
@onready var _player: CharacterBody2D = $Entities/Player


func _ready() -> void:
	# The isometric layout does not put cell (0,0) at the origin, so ask the
	# tilemap where the centre is instead of working it out here.
	var centre := Vector2i(_water.grid_size / 2, _water.grid_size / 2)
	_player.position = _water.map_to_local(centre)
	_set_camera_limits()


## Fence the camera to the painted water so the grey void never shows. The
## extremes of an isometric patch are its four corner cells, so asking the
## tilemap where those land covers the whole diamond's bounding box.
func _set_camera_limits() -> void:
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam == null:
		return
	var r := _water.get_used_rect()
	if r.size == Vector2i.ZERO:
		return
	var corners := [
		r.position, Vector2i(r.end.x - 1, r.position.y),
		Vector2i(r.position.x, r.end.y - 1), r.end - Vector2i.ONE,
	]
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for c in corners:
		var p := _water.map_to_local(c)
		lo = lo.min(p)
		hi = hi.max(p)
	var pad := Vector2(_water.tile_set.tile_size)
	cam.limit_left = int(lo.x - pad.x)
	cam.limit_right = int(hi.x + pad.x)
	cam.limit_top = int(lo.y - pad.y)
	cam.limit_bottom = int(hi.y + pad.y)


func _physics_process(_delta: float) -> void:
	var cell := _water.local_to_map(_water.to_local(_player.global_position))
	_player.in_water = _water.is_fully_secondary(cell)
