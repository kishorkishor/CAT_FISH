extends SceneTree
## Fills the bag and the farm, opens the panel, photographs it.
var _frames := 0
var _out := ""

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else "panel.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		var world := root.get_node("World")
		var farm: Node2D = world.get_node("Farm")
		var water: TileMapLayer = world.get_node("Water")
		var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
		root.get_node("Game").money = 348
		root.get_node("Game").add_item("tuna", 1)
		root.get_node("Game").add_item("snapper", 3)
		root.get_node("Game").add_item("tomato", 7)
		root.get_node("Game").add_item("carrot", 4)
		for i in 5:
			var cell := centre + Vector2i(i - 2, 2)
			farm.till(cell)
			if i < 4:
				farm.plant(cell, load("res://data/crops/%s.tres" % ["tomato","carrot","corn","herb"][i]))
				if i < 2:
					farm.plots[cell].stage = 3
					farm.water(cell)
		world.get_node("Buildings").place(centre + Vector2i(-4, -4), load("res://data/build/palm.tres"), false)
		world.get_node("Buildings").place(centre + Vector2i(-5, -4), load("res://data/build/lamp.tres"), false)
	if _frames == 6:
		root.get_node("World/Panel").toggle()
	if _frames < 30:
		return false
	root.get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	return true
