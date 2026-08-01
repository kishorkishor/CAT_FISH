extends SceneTree
## Renders the cat part-way through each tool action, one PNG each.
##
##   godot --path . --resolution 540x960 --script res://tools/shot_action.gd -- <dir>
##
## Not compatible with --headless - there is no rendered frame to capture.

## Which frame of the action to photograph. The pose that says what the cat is
## doing is past the wind-up, so waiting a fixed number of ticks lands on the
## cat looking like it is standing still.
const AT_FRAME := 4

var _dir := "."
var _shots := ["till", "plant", "water", "harvest"]
var _index := 0
var _frames := 0
var _cell := Vector2i.ZERO


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_dir = argv[0] if argv.size() > 0 else "."
	root.add_child((load("res://scenes/world.tscn") as PackedScene).instantiate())


func _use(interactor: Node2D) -> void:
	var ev := InputEventAction.new()
	ev.action = "use"
	ev.pressed = true
	interactor._unhandled_input(ev)


## Each shot needs the plot in the right state first: you cannot photograph a
## harvest without something ripe to pick.
func _arm(which: String) -> void:
	var world := root.get_node("World")
	var water: TileMapLayer = world.get_node("Water")
	var player = world.get_node("Entities/Player")
	var interactor: Node2D = world.get_node("Interactor")
	var farm: Node2D = world.get_node("Farm")
	var clock := root.get_node("Clock")

	# Noon, so the day/night tint is not what the screenshot is of.
	clock.hour = 12.0

	player.global_position = water.to_global(water.map_to_local(
		Vector2i(water.grid_size / 2 + 1, water.grid_size / 2 - 6)))
	_cell = interactor.target_cell()

	match which:
		"till":
			farm.clear(_cell)
			interactor.tool = Tools.HOE
		"plant":
			farm.clear(_cell)
			farm.till(_cell)
			interactor.tool = Tools.HAND
		"water":
			farm.clear(_cell)
			farm.till(_cell)
			farm.plant(_cell, load("res://data/crops/carrot.tres"))
			interactor.tool = Tools.CAN
		"harvest":
			farm.clear(_cell)
			farm.till(_cell)
			var crop: CropData = load("res://data/crops/carrot.tres")
			farm.plant(_cell, crop)
			var day := 2
			while not crop.is_ripe(farm.plots[_cell].stage) and day < 30:
				farm.water(_cell)
				clock.day_passed.emit(day)
				day += 1
			interactor.tool = Tools.HAND
	_use(interactor)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_arm(_shots[_index])
		return false
	if _frames < 4:
		return false

	var sprite: AnimatedSprite2D = root.get_node("World/Entities/Player/Sprite")
	# Wait for *this* action, then for its money frame. Checking the frame alone
	# fires instantly on the tail of the previous action, which is still on screen
	# at a high frame index - every shot came out one action behind.
	var started: bool = sprite.animation.begins_with("%s_" % _shots[_index])
	if (not started or sprite.frame < AT_FRAME) and _frames < 150:
		return false

	var path := "%s/action_%s.png" % [_dir, _shots[_index]]
	var err := root.get_texture().get_image().save_png(path)
	print("wrote %s" % path if err == OK else "save failed: %d" % err)

	_index += 1
	if _index >= _shots.size():
		return true
	_frames = 0
	return false
