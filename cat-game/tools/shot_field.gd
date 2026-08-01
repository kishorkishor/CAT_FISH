extends SceneTree
## The starter field with crops in it, and a second one being marked out.
var _dir := "."
var _frames := 0


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_dir = argv[0] if argv.size() > 0 else "."
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		var world := root.get_node("World")
		var water: TileMapLayer = world.get_node("Water")
		var fields: Node2D = world.get_node("Fields")
		var farm: Node2D = world.get_node("Farm")
		var player = world.get_node("Entities/Player")
		root.get_node("Clock").hour = 12.0
		var crop: CropData = load("res://data/crops/carrot.tres")
		# Sow part of the starter field so the grid reads as a farm, not a stencil.
		var rect: Rect2i = fields.fields[0]
		var n := 0
		for y in rect.size.y:
			for x in rect.size.x:
				var cell := rect.position + Vector2i(x, y)
				if (x + y) % 2 == 0 and n < 10:
					farm.till(cell)
					farm.plant(cell, crop)
					farm.plots[cell].stage = 1 + (n % 3)
					farm._refresh_sprite(farm.plots[cell])
					n += 1
		farm.queue_redraw()
		# ...and show a second field mid-mark, in green.
		fields.pending = Rect2i(rect.position + Vector2i(6, 0), Vector2i(4, 8))
		fields.pending_ok = true
		fields.showing_pending = true
		fields.queue_redraw()
		player.global_position = water.to_global(water.map_to_local(
			rect.position + Vector2i(2, -4)))
		return false
	if _frames < 16:
		return false
	var path := "%s/field.png" % _dir
	print("wrote %s" % path if root.get_texture().get_image().save_png(path) == OK else "failed")
	return true
