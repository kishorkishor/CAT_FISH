extends Node2D
## The float: bobs on the water while waiting, then dips hard when a fish bites.

## Pixels the float rides up and down while nothing is biting.
@export var idle_bob := 1.5
## How far it is yanked under once something takes the bait.
@export var bite_dip := 4.0

var _biting := false
var _time := 0.0

@onready var _sprite: Sprite2D = $Sprite


func bite() -> void:
	_biting = true


func _process(delta: float) -> void:
	_time += delta
	if _biting:
		# A quick stutter rather than a smooth ride - it should read as a fish
		# pulling, not as the float drifting.
		_sprite.position.y = bite_dip * (1.0 + sin(_time * 22.0)) * 0.5
	else:
		_sprite.position.y = sin(_time * 2.2) * idle_bob
