extends SceneTree
## Captures the player at several positions to see where tiles draw over it.
##
##   godot --path . --resolution 540x960 --script res://tools/probe_sort.gd -- <scene> <out_dir>

const SETTLE := 12
const OFFSETS: Array[Vector2] = [
	Vector2(0, 0),
	Vector2(0, 8),
	Vector2(0, 16),
	Vector2(16, 8),
	Vector2(-16, 8),
	Vector2(0, 24),
]

var _root: Node = null
var _player: Node2D = null
var _base := Vector2.ZERO
var _index := 0
var _frames := 0
var _out := ""


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var scene_path: String = argv[0] if argv.size() > 0 else "res://scenes/world.tscn"
	_out = argv[1] if argv.size() > 1 else "screenshots"

	_root = (load(scene_path) as PackedScene).instantiate()
	root.add_child(_root)
	_player = _root.get_node("Entities/Player")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE:
		return false
	if _base == Vector2.ZERO:
		_base = _player.position

	_player.position = _base + OFFSETS[_index]
	if _frames < SETTLE + 2:
		return false

	var image := root.get_texture().get_image()
	# Crop tight around the player so the overlap is actually visible.
	var cam := _player.get_node("Camera2D") as Camera2D
	var centre := Vector2(image.get_width(), image.get_height()) * 0.5
	var box := Rect2i(int(centre.x) - 60, int(centre.y) - 80, 120, 130)
	image.get_region(box).save_png("%s/sort_%d.png" % [_out, _index])

	_index += 1
	_frames = SETTLE
	if _index >= OFFSETS.size():
		print("wrote %d probes to %s" % [OFFSETS.size(), _out])
		return true
	return false
