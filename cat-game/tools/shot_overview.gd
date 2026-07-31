extends SceneTree
## Boots the world zoomed out far enough to fit the whole island, saves one frame.
##
##   godot --path . --resolution 960x960 --script res://tools/shot_overview.gd -- <out.png> [zoom]
##
## Not compatible with --headless - there is no rendered frame to capture.

const SETTLE_FRAMES := 20

var _frames := 0
var _out := ""
var _zoom := 0.3


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else "overview.png"
	if argv.size() > 1:
		_zoom = float(argv[1])
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		var cam: Camera2D = root.get_node("World/Entities/Player/Camera2D")
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
