extends SceneTree
## Renders the cat in each of the four gaits this pass touched, one PNG each.
##
##   godot --path . --resolution 540x960 --script res://tools/shot_gait.gd -- <dir>
##
## Not compatible with --headless - there is no rendered frame to capture.

const SETTLE := 26

var _dir := "."
var _shots := ["swim", "deepswim", "hop", "pounce"]
var _index := 0
var _frames := 0
var _armed := false


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_dir = argv[0] if argv.size() > 0 else "."
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _release() -> void:
	for action in ["move_right", "run", "jump"]:
		Input.action_release(action)


func _arm(which: String) -> void:
	var world := root.get_node("World")
	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)

	var wanted_depth := 0
	match which:
		"swim": wanted_depth = 2
		"deepswim": wanted_depth = 3
	var cell := centre
	for step in range(0, water.grid_size / 2):
		var candidate := centre + Vector2i(step, 0)
		if int(water.depth_at(candidate)) == wanted_depth:
			cell = candidate
			break
	player.global_position = water.map_to_local(cell)
	_release()
	Input.action_press("move_right")
	if which == "pounce":
		Input.action_press("run")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_arm(_shots[_index])
		_armed = true
		return false
	if not _armed:
		return false
	# The hop and the pounce have to be triggered late, so the shot lands
	# mid-air rather than on the frame the key went down.
	if _frames == SETTLE - 8 and _shots[_index] in ["hop", "pounce"]:
		Input.action_press("jump")
	if _frames == SETTLE - 7:
		Input.action_release("jump")
	if _frames < SETTLE:
		return false

	var path := "%s/gait_%s.png" % [_dir, _shots[_index]]
	var err := root.get_texture().get_image().save_png(path)
	print("wrote %s" % path if err == OK else "save failed: %d" % err)

	_index += 1
	if _index >= _shots.size():
		return true
	_frames = 0
	_armed = false
	return false
