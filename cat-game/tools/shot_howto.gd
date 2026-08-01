extends SceneTree
## Full-screen frames of each step of planting, HUD included.
const STEPS := ["1_hoe", "2_tilled", "3_seed", "4_planted", "5_can"]
var _dir := "."
var _index := 0
var _frames := 0
var _cell := Vector2i.ZERO


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_dir = argv[0] if argv.size() > 0 else "."
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _use(i: Node2D) -> void:
	var ev := InputEventAction.new()
	ev.action = "use"
	ev.pressed = true
	i._unhandled_input(ev)


func _arm(step: String) -> void:
	var world := root.get_node("World")
	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")
	var interactor: Node2D = world.get_node("Interactor")
	var farm: Node2D = world.get_node("Farm")
	root.get_node("Clock").hour = 12.0
	player.global_position = water.to_global(water.map_to_local(
		Vector2i(water.grid_size / 2 + 1, water.grid_size / 2 - 6)))
	_cell = interactor.target_cell()
	match step:
		"1_hoe":
			farm.clear(_cell)
			interactor.tool = Tools.HOE
		"2_tilled":
			farm.clear(_cell); farm.till(_cell)
			interactor.tool = Tools.HOE
		"3_seed":
			farm.clear(_cell); farm.till(_cell)
			interactor.tool = Tools.HAND
		"4_planted":
			farm.clear(_cell); farm.till(_cell)
			farm.plant(_cell, load("res://data/crops/carrot.tres"))
			interactor.tool = Tools.HAND
		"5_can":
			farm.clear(_cell); farm.till(_cell)
			farm.plant(_cell, load("res://data/crops/carrot.tres"))
			interactor.tool = Tools.CAN


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_arm(STEPS[_index])
		return false
	if _frames < 12:
		return false
	var path := "%s/howto_%s.png" % [_dir, STEPS[_index]]
	print("wrote %s" % path if root.get_texture().get_image().save_png(path) == OK else "failed")
	_index += 1
	if _index >= STEPS.size():
		return true
	_frames = 0
	return false
