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


func _physics_process(_delta: float) -> void:
	var cell := _water.local_to_map(_water.to_local(_player.global_position))
	_player.in_water = _water.is_fully_secondary(cell)
