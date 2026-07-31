extends SceneTree
var _frames := 0
var _out := ""
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else "shop.png"
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		var world := root.get_node("World")
		root.get_node("Game").money = 240
		root.get_node("Game").add_item("tuna", 1)
		root.get_node("Game").add_item("snapper", 2)
		root.get_node("Game").add_item("tomato", 4)
		var keeper = world.get_node("Entities/Shopkeeper")
		world.get_node("Entities/Player").global_position = keeper.global_position + Vector2(0, 14)
	if _frames == 6:
		root.get_node("World/Shop").open()
	if _frames < 26:
		return false
	root.get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	return true
