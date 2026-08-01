extends SceneTree
## The cat has to be doing something for the whole fight. It used to stand
## frozen from the moment the line went out until the fish was in the bag - the
## one stretch of the game where nothing moved was the mechanic the game is
## built around.

var failures := 0

const DIRECTIONS: PackedStringArray = [
	"south", "south-west", "west", "north-west",
	"north", "north-east", "east", "south-east",
]


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player = world.get_node("Entities/Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var rod: SpriteFrames = player.frames_rod

	# --- the art is all there -----------------------------------------------
	for action in ["cast", "reel", "catch"]:
		var missing := PackedStringArray()
		for direction in DIRECTIONS:
			if not rod.has_animation("%s_%s" % [action, direction]):
				missing.append(direction)
		_ok(missing.is_empty(), "%s has all 8 facings%s"
			% [action, "" if missing.is_empty() else " - missing %s" % [missing]])

	# Reeling is the one that loops: the fight lasts as long as it lasts.
	if rod.has_animation("reel_south"):
		_ok(rod.get_animation_loop("reel_south"), "reeling loops")
	if rod.has_animation("cast_south"):
		_ok(not rod.get_animation_loop("cast_south"), "casting is a one-shot")
	if rod.has_animation("catch_south"):
		_ok(not rod.get_animation_loop("catch_south"), "landing it is a one-shot")

	# --- the states actually drive the sprite --------------------------------
	player.holding_rod = true
	await physics_frame

	player.play_action("cast")
	await physics_frame
	_ok(sprite.sprite_frames == rod, "casting uses the rod-carrying rig")
	_ok(sprite.animation.begins_with("cast_"), "and plays %s" % sprite.animation)

	# A held action must outlast its own frame count - the fight has no
	# deadline, so a reel that timed itself out would drop the cat back to idle
	# halfway through a fish.
	player.play_action("reel", true)
	var frames := int(rod.get_frame_count("reel_south") * 4)
	for i in frames:
		await physics_frame
	_ok(player.is_acting() and sprite.animation.begins_with("reel_"),
		"still reeling after %d frames" % frames)

	player.stop_action()
	await physics_frame
	_ok(not player.is_acting(), "and it stops when the fight does")

	player.play_action("catch")
	await physics_frame
	_ok(sprite.animation.begins_with("catch_"), "landing it plays %s" % sprite.animation)

	quit(failures)
