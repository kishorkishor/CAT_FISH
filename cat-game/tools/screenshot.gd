extends SceneTree
## Boots a scene, saves one frame, quits.
##
##   godot --path . --resolution 720x1280 --script res://tools/screenshot.gd -- <scene> <out.png>
##
## Not compatible with --headless - there is no rendered frame to capture.

const SETTLE_FRAMES := 20

var _frames := 0
var _out := ""


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var scene_path := argv[0] if argv.size() > 0 else "res://scenes/world.tscn"
	_out = argv[1] if argv.size() > 1 else "shot.png"

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("could not load %s" % scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	var image := root.get_texture().get_image()
	var err := image.save_png(_out)
	if err != OK:
		push_error("save_png failed: %d" % err)
	else:
		print("wrote %s (%dx%d)" % [_out, image.get_width(), image.get_height()])
	return true
