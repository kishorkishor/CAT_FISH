extends SceneTree
## Parks the cat just behind and just in front of Tree1 and saves both frames,
## so occlusion can be judged from pixels rather than assumed from code.
##
##   godot --path . --resolution 400x400 --script res://tools/shot_sort.gd -- <behind.png> <front.png>

var _out := []
var _frames := 0
var _shot := 0
var _tree := Vector2.ZERO


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	var player = root.get_node("World/Entities/Player")
	if _frames == 2:
		_tree = root.get_node("World/Entities/Tree1").global_position
		var cam: Camera2D = player.get_node("Camera2D")
		cam.zoom = Vector2(2, 2)
	if _frames == 3:
		player.global_position = _tree + Vector2(0, -14)   # behind: smaller y
	if _frames == 20:
		_save(0)
		player.global_position = _tree + Vector2(0, 20)    # in front: larger y
	if _frames == 40:
		_save(1)
		return true
	return false


func _save(i: int) -> void:
	# Keep the camera on the tree, not the cat, so both shots frame the same spot.
	var image := root.get_texture().get_image()
	image.save_png(_out[i])
	print("wrote %s" % _out[i])
