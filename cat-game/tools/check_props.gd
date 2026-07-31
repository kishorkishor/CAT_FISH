extends SceneTree
## Asserts props behave: solid things block the cat, walkable things do not, and
## every prop's art is seated on its own node origin so y-sorting is honest.

func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player = world.get_node("Entities/Player")
	var entities := world.get_node("Entities")
	var failures := 0

	# --- Art must sit above its origin, never below --------------------------
	# A prop whose sprite node is offset upward instead of its texture would sort
	# by its treetop and stop occluding anything. The node stays at y=0; only the
	# drawn pixels move.
	var checked := 0
	for prop in entities.get_children():
		if prop == player:
			continue
		for child in prop.get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				checked += 1
				if not is_equal_approx(child.position.y, 0.0):
					print("FAIL %s art moved by position (%.1f), not offset" % [prop.name, child.position.y])
					failures += 1
				if child.offset.y >= 0.0:
					print("FAIL %s art is not lifted above its base" % prop.name)
					failures += 1
	print("ok   %d prop sprites seated on their origin" % checked)

	# --- Solid props block, walkable ones do not ----------------------------
	for spec in [["House", true], ["Shop", true], ["Tree1", true], ["Pier", false]]:
		var prop = entities.get_node(spec[0])
		var solid: bool = spec[1]
		var has_body := false
		for child in prop.get_children():
			if child is StaticBody2D:
				has_body = true
		if has_body != solid:
			print("FAIL %s solid=%s but expected %s" % [prop.name, has_body, solid])
			failures += 1
			continue
		if not solid:
			print("ok   %s is walkable" % prop.name)
			continue
		# Walk at it from below and check it does not end up inside.
		player.global_position = prop.global_position + Vector2(0, 60)
		Input.action_press("move_up")
		for i in 90:
			await physics_frame
		Input.action_release("move_up")
		var gap: float = player.global_position.y - prop.global_position.y
		if gap > 0.0:
			print("ok   %s stopped the cat %.0fpx short" % [prop.name, gap])
		else:
			print("FAIL %s let the cat through (%.0f past)" % [prop.name, -gap])
			failures += 1

	quit(failures)
