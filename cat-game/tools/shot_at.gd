extends SceneTree
## Boots the world, parks the camera at a world position, saves one frame.
##
##   godot --path . --resolution 720x1280 --script res://tools/shot_at.gd -- <out.png> <x> <y> [zoom]

const SETTLE_FRAMES := 25

var _frames := 0
var _out := ""
var _pos := Vector2.ZERO
var _zoom := 1.0


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else "shot.png"
	_pos = Vector2(float(argv[1]), float(argv[2])) if argv.size() > 2 else Vector2.ZERO
	if argv.size() > 3:
		_zoom = float(argv[3])
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		var player = root.get_node("World/Entities/Player")
		player.global_position = _pos
		var cam: Camera2D = player.get_node("Camera2D")
		cam.zoom = Vector2(_zoom, _zoom)
	if _frames < SETTLE_FRAMES:
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png(_out)
	if err != OK:
		push_error("save_png failed: %d" % err)
	else:
		print("wrote %s" % _out)
	return true
