extends SceneTree
## Plants every crop at every stage in a grid and photographs the field, so the
## whole growth set can be judged in the game rather than as loose PNGs.

var _frames := 0
var _out := ""

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else "farm.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		var world := root.get_node("World")
		var farm: Node2D = world.get_node("Farm")
		var player = world.get_node("Entities/Player")
		var water: TileMapLayer = world.get_node("Water")
		var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
		var crops := ["carrot", "tomato", "corn", "herb"]
		for row in crops.size():
			var crop: CropData = load("res://data/crops/%s.tres" % crops[row])
			for stage in 4:
				var cell := centre + Vector2i(row - 2, stage * 2 - 6)
				farm.till(cell)
				farm.plant(cell, crop)
				farm.plots[cell].stage = stage
				farm.water(cell)
				farm._refresh_sprite(farm.plots[cell])
		farm.queue_redraw()
		player.global_position = water.map_to_local(centre + Vector2i(-2, 4))
		var cam: Camera2D = player.get_node("Camera2D")
		cam.zoom = Vector2(2.2, 2.2)
	if _frames < 25:
		return false
	root.get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	return true
