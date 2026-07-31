extends SceneTree
## Draws every collision polygon over the world so the footprints can be judged
## against the art instead of guessed at.

var _frames := 0
var _out := ""

class Overlay extends Node2D:
	var shapes: Array = []
	func _draw() -> void:
		for entry in shapes:
			var pts: PackedVector2Array = entry[0]
			var closed := PackedVector2Array(pts)
			closed.append(pts[0])
			draw_polyline(closed, entry[1], 1.0)
			draw_circle(entry[2], 1.5, Color(1, 1, 0))

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else "hitbox.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		var world := root.get_node("World")
		var player = world.get_node("Entities/Player")
		player.global_position = Vector2(float(OS.get_cmdline_user_args()[1]),
										 float(OS.get_cmdline_user_args()[2]))
		player.get_node("Camera2D").zoom = Vector2(2, 2)
		var overlay := Overlay.new()
		overlay.z_index = 4096
		world.add_child(overlay)
		for prop in world.get_node("Entities").get_children():
			for child in prop.get_children():
				if child is StaticBody2D:
					for sub in child.get_children():
						if sub is CollisionPolygon2D and not sub.disabled:
							var pts := PackedVector2Array()
							for p in sub.polygon:
								pts.append(world.to_local(sub.to_global(p)))
							overlay.shapes.append([pts, Color(1, 0.2, 0.2), world.to_local(prop.global_position)])
			if prop == player:
				for child in prop.get_children():
					if child is CollisionPolygon2D:
						var pts := PackedVector2Array()
						for p in child.polygon:
							pts.append(world.to_local(child.to_global(p)))
						overlay.shapes.append([pts, Color(0.3, 1, 0.3), world.to_local(prop.global_position)])
		overlay.queue_redraw()
	if _frames < 22:
		return false
	root.get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	return true
