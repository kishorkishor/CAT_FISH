extends SceneTree
## Checks that keyboard input resolves to the facing a player would expect.
##
##   godot --headless --path . --script res://tools/check_dirs.gd
##
## The mapping is easy to get mirrored - an earlier version handed back east for
## west and both diagonals were wrong - and the bug is nearly invisible in motion
## because the walk cycle still plays either way. Exits non-zero on a mismatch.

const CASES := {
	"right": [Vector2(1, 0), "east"],
	"left": [Vector2(-1, 0), "west"],
	"down": [Vector2(0, 1), "south"],
	"up": [Vector2(0, -1), "north"],
	"down-right": [Vector2(0.707, 0.707), "south-east"],
	"down-left": [Vector2(-0.707, 0.707), "south-west"],
	"up-right": [Vector2(0.707, -0.707), "north-east"],
	"up-left": [Vector2(-0.707, -0.707), "north-west"],
}


func _initialize() -> void:
	var player = load("res://scripts/player.gd").new()
	var failed := 0
	for key in CASES:
		var input: Vector2 = CASES[key][0]
		var expected: String = CASES[key][1]
		var got: String = player._direction_name(input)
		if got != expected:
			printerr("%-11s expected %-11s got %s" % [key, expected, got])
			failed += 1
	player.free()

	if failed > 0:
		printerr("%d/%d direction mappings wrong" % [failed, CASES.size()])
		quit(1)
		return
	print("all %d direction mappings correct" % CASES.size())
	quit()
