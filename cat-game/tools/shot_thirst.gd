extends SceneTree
## A row of plots in every water state, so the bars and soils can be compared.
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
		var farm: Node2D = world.get_node("Farm")
		var player = world.get_node("Entities/Player")
		root.get_node("Clock").hour = 12.0
		var crop: CropData = load("res://data/crops/carrot.tres")
		var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
		# full, half, empty-and-wilting, dead, and a fertilised one
		var specs := [[1.0, false, false], [0.45, false, false], [0.0, false, false],
			[0.0, true, false], [1.0, false, true]]
		for i in specs.size():
			var cell := centre + Vector2i(i * 2 - 5, 4)
			farm.till(cell)
			farm.plant(cell, crop)
			var plot = farm.plots[cell]
			plot.stage = 2
			plot.water = specs[i][0]
			plot.dead = specs[i][1]
			plot.fertilised = specs[i][2]
			plot.wilt_days = 1 if specs[i][0] <= 0.0 else 0
			farm._refresh_sprite(plot)
		farm.queue_redraw()
		player.global_position = water.to_global(water.map_to_local(centre + Vector2i(0, -2)))
		return false
	if _frames < 14:
		return false
	var path := "%s/thirst.png" % _dir
	print("wrote %s" % path if root.get_texture().get_image().save_png(path) == OK else "failed")
	return true
