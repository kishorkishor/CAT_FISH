extends Node2D
## Drops the player on the middle of the island.
##
## Ground is a plain sibling drawn before Entities rather than y-sorted against
## them. Every cell sits at the same elevation, so the floor never has cause to
## occlude anything standing on it; sorting the two together only ever produced
## tiles clipping the player's feet near a cell boundary.

@onready var _ground: TileMapLayer = $Ground
@onready var _player: CharacterBody2D = $Entities/Player


func _ready() -> void:
	# The isometric layout does not put cell (0,0) at the origin, so ask the
	# tilemap where the centre is instead of working it out here.
	var centre := Vector2i(_ground.grid_size / 2, _ground.grid_size / 2)
	_player.position = _ground.map_to_local(centre)
