extends Node2D
## Drops the player on the middle of the island.

@onready var _ground: TileMapLayer = $Ground
@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	# The isometric layout does not put cell (0,0) at the origin, so ask the
	# tilemap where the centre is instead of working it out here.
	var centre := Vector2i(_ground.grid_size / 2, _ground.grid_size / 2)
	_player.position = _ground.map_to_local(centre)
