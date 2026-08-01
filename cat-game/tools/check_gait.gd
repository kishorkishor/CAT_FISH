extends SceneTree
## Asserts the cat leaves the ground on the rig it was travelling on, and that the
## open sea does not merely look like the shallows with the cat lower down.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _release_all() -> void:
	for action in ["move_right", "move_left", "move_up", "move_down", "run", "jump"]:
		Input.action_release(action)


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)

	var sprint: SpriteFrames = player.frames_sprint
	var upright: SpriteFrames = player.frames_upright
	var missing := PackedStringArray()
	for direction in ["south", "south-west", "west", "north-west",
			"north", "north-east", "east", "south-east"]:
		if not sprint.has_animation("jump_%s" % direction):
			missing.append(direction)
	_ok(missing.is_empty(), "the four-legged rig has a jump for every facing%s"
		% ("" if missing.is_empty() else " - missing %s" % [missing]))

	# A standing hop and a hop out of a sprint have to come off different rigs,
	# otherwise the cat rears onto two legs mid-stride to jump.
	for run_held in [false, true]:
		var label := "pounce" if run_held else "hop"
		player.global_position = water.to_global(water.map_to_local(centre))
		_release_all()
		await physics_frame
		Input.action_press("move_right")
		if run_held:
			Input.action_press("run")
		for i in 8:
			await physics_frame
		Input.action_press("jump")
		await physics_frame
		Input.action_release("jump")
		await physics_frame

		_ok(player.is_jumping(), "%s: the cat is airborne" % label)
		var on_sprint: bool = sprite.sprite_frames == sprint
		_ok(on_sprint == run_held, "%s: rig is %s" % [label,
			"four-legged" if on_sprint else "upright"])
		_ok(sprite.animation.begins_with("jump_"),
			"%s: plays %s" % [label, sprite.animation])

		# A pounce that drops to walking speed the moment the paws leave the
		# ground is the bug this latch exists to prevent.
		if run_held:
			_ok(player.velocity.length() > player.walk_speed * 1.2,
				"pounce: keeps sprint speed in the air (%.0f px/s)" % player.velocity.length())

		# The arc is timed in seconds and the animation in frames. If the rate is
		# not stretched to fit, the cat lands having played only the first half of
		# its own leap and never showing the crouch it ends on.
		var seen := {}
		var anim: String = sprite.animation
		while player.is_jumping():
			seen[sprite.frame] = true
			await physics_frame
		var total: int = sprite.sprite_frames.get_frame_count(anim)
		_ok(seen.size() == total,
			"%s: all %d frames of %s play before landing (saw %d)" % [
				label, total, anim, seen.size()])
		_ok(sprite.sprite_frames == upright or run_held, "%s: lands cleanly" % label)

	# The shallows and the open sea, side by side.
	_release_all()
	var sample := {}
	for step in range(0, water.grid_size / 2):
		var cell := centre + Vector2i(step, 0)
		var d: int = water.depth_at(cell)
		if not sample.has(d):
			sample[d] = cell
	_ok(sample.has(2) and sample.has(3), "found both a swimmable and a deep cell")

	var seen := {}
	for depth in [2, 3]:
		if not sample.has(depth):
			continue
		player.global_position = water.to_global(water.map_to_local(sample[depth]))
		Input.action_press("move_right")
		for i in 8:
			await physics_frame
		var low := sprite.offset.y
		var high := sprite.offset.y
		for i in 40:
			await physics_frame
			low = minf(low, sprite.offset.y)
			high = maxf(high, sprite.offset.y)
		seen[depth] = {
			"anim": sprite.animation,
			"speed": sprite.speed_scale,
			"swell": high - low,
			"ripple": player.get_node("Ripple").scale.x,
		}
		Input.action_release("move_right")

	if seen.has(2) and seen.has(3):
		_ok(seen[2].anim != seen[3].anim,
			"the deep plays its own stroke: %s vs %s" % [seen[2].anim, seen[3].anim])
		_ok(seen[3].speed < seen[2].speed,
			"the deep stroke is slower (%.2f vs %.2f)" % [seen[3].speed, seen[2].speed])
		_ok(seen[3].swell > 1.0 and seen[2].swell < 0.5,
			"only the deep rides a swell (%.1fpx vs %.1fpx)" % [seen[3].swell, seen[2].swell])
		_ok(seen[3].ripple > seen[2].ripple,
			"the deep wake spreads wider (%.2f vs %.2f)" % [seen[3].ripple, seen[2].ripple])

	quit(failures)
