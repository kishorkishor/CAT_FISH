extends Node2D
## An island: grass in the middle, a sand beach, shallows, then open sea.
##
## Three 16-tile corner sets stacked, each one leaving its empty cells unpainted
## so the layer beneath shows through. Sea paints shallow water into deep, Water
## paints sand into shallow, Land paints grass into sand. No set knows about the
## others - four terrains come out of the stacking, not out of a bigger tileset.
##
## The radii are what tie the picture to the rules: the Sea layer's shallow ring
## ends exactly where GroundBuilder.depth_at() stops calling the water shallow,
## so the colour under the cat always agrees with the animation it is playing.

@onready var _sea: TileMapLayer = $Sea
@onready var _water: TileMapLayer = $Water
@onready var _land: TileMapLayer = $Land
@onready var _player: CharacterBody2D = $Entities/Player


func _ready() -> void:
	# The isometric layout does not put cell (0,0) at the origin, so ask the
	# tilemap where the centre is instead of working it out here.
	var centre := Vector2i(_water.grid_size / 2, _water.grid_size / 2)
	_player.position = _water.map_to_local(centre)
	_set_camera_limits()
	# Deferred: the farm and the buildings register themselves in their own
	# _ready, and loading before that would restore into nothing.
	if Game.resume_on_load:
		Game.resume_on_load = false
		call_deferred("_resume")


func _resume() -> void:
	if Game.load_game():
		Events.notice.emit("welcome back - day %d" % Clock.day)


## Fence the camera to the painted water so the grey void never shows. The
## extremes of an isometric patch are its four corner cells, so asking the
## tilemap where those land covers the whole diamond's bounding box.
func _set_camera_limits() -> void:
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam == null:
		return
	# Measured on the bottom layer: it is the only one that paints every cell, so
	# the layers above with skip_empty would fence the camera to the island.
	var r := _sea.get_used_rect()
	if r.size == Vector2i.ZERO:
		return
	var corners := [
		r.position, Vector2i(r.end.x - 1, r.position.y),
		Vector2i(r.position.x, r.end.y - 1), r.end - Vector2i.ONE,
	]
	var lo := Vector2.INF
	var hi := -Vector2.INF
	for c in corners:
		# Camera limits are global, and the world is shifted so that the middle of
		# the patch sits on the origin. Reading the cell position as local would
		# fence the camera around a rectangle the island is not in.
		var p := _water.to_global(_water.map_to_local(c))
		lo = lo.min(p)
		hi = hi.max(p)
	var pad := Vector2(_sea.tile_set.tile_size)
	cam.limit_left = int(lo.x - pad.x)
	cam.limit_right = int(hi.x + pad.x)
	cam.limit_top = int(lo.y - pad.y)
	cam.limit_bottom = int(hi.y + pad.y)


func _physics_process(_delta: float) -> void:
	var cell := _water.local_to_map(_water.to_local(_player.global_position))
	_player.water_depth = _water.depth_at(cell)
	var boat: Node2D = get_node_or_null("Entities/Boat")
	if boat != null:
		boat.water_depth = _water.depth_at(
			_water.local_to_map(_water.to_local(boat.global_position)))
