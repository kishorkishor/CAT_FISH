extends SceneTree
var _frames := 0
var _out := ""
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else "title.png"
	root.get_node("Game").money = 412
	root.get_node("Clock").day = 9
	root.get_node("Game").save_game()
	root.add_child((load("res://scenes/title.tscn") as PackedScene).instantiate())
func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 20:
		return false
	root.get_texture().get_image().save_png(_out)
	print("wrote %s" % _out)
	return true
