extends CharacterBody2D
## Placeholder body, real input. Swap the sprite for the cat later; the movement
## maths stays the same.

@export var speed: float = 220.0

## Cells are twice as wide as they are tall. Without halving vertical movement,
## holding up crosses the island in half the time holding right does and the
## ground reads as sliding under you.
const ISO_RATIO := 0.5


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = Vector2(input.x, input.y * ISO_RATIO) * speed
	move_and_slide()
