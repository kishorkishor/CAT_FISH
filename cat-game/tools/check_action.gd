extends SceneTree
## Asserts the cat visibly does the thing: a swing for the hoe, a pour for the
## can, a crouch for sowing and picking - and nothing at all when the use failed.

var failures := 0

const ACTIONS: PackedStringArray = ["till", "water", "plant", "harvest"]
const DIRECTIONS: PackedStringArray = [
	"south", "south-west", "west", "north-west",
	"north", "north-east", "east", "south-east",
]


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _use(interactor: Node2D) -> void:
	var ev := InputEventAction.new()
	ev.action = "use"
	ev.pressed = true
	interactor._unhandled_input(ev)


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player = world.get_node("Entities/Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var interactor: Node2D = world.get_node("Interactor")
	var farm: Node2D = world.get_node("Farm")
	var water: TileMapLayer = world.get_node("Water")
	var centre := Vector2i(water.grid_size / 2, water.grid_size / 2)
	var frames: SpriteFrames = player.frames_upright

	# --- the art exists at all --------------------------------------------
	for action in ACTIONS:
		var missing := PackedStringArray()
		for direction in DIRECTIONS:
			if not frames.has_animation("%s_%s" % [action, direction]):
				missing.append(direction)
		_ok(missing.is_empty(), "%s has all 8 facings%s"
			% [action, "" if missing.is_empty() else " - missing %s" % [missing]])
		if frames.has_animation("%s_south" % action):
			_ok(not frames.get_animation_loop("%s_south" % action),
				"%s is a one-shot, not a loop" % action)

	# One plot, worked through its whole life facing south, so the target cell
	# never moves under us - turning would aim the tool at a different tile.
	player.global_position = water.to_global(water.map_to_local(centre + Vector2i(1, -6)))
	await physics_frame
	var cell: Vector2i = interactor.target_cell()

	# --- tilling swings ----------------------------------------------------
	interactor.tool = Tools.HOE
	await physics_frame
	var plots_before: int = farm.plots.size()
	_use(interactor)
	await physics_frame
	_ok(farm.plots.size() == plots_before + 1, "the hoe tilled a plot")
	_ok(player.is_acting(), "the cat is mid-swing")
	_ok(sprite.animation.begins_with("till_"), "playing %s" % sprite.animation)

	# ...and stops on its own rather than swinging forever.
	var waited := 0.0
	while player.is_acting() and waited < 3.0:
		await physics_frame
		waited += 1.0 / 60.0
	_ok(not player.is_acting(), "the swing ends by itself after %.2fs" % waited)
	await physics_frame
	_ok(sprite.animation.begins_with("idle_"), "back to %s" % sprite.animation)

	# --- sowing crouches ----------------------------------------------------
	interactor.tool = Tools.HAND
	await physics_frame
	_use(interactor)
	await physics_frame
	_ok(farm.plots[cell].crop != null, "a seed went in")

	# Where the crop is *drawn*, not just where the data says it is. A cell
	# position is local to the tilemap and a sprite position is local to the farm;
	# treating one as the other put the crops a whole map away and no assertion
	# about plots or stages noticed.
	await process_frame
	var art: Sprite2D = farm.plots[cell].sprite
	var want := water.to_global(water.map_to_local(cell))
	_ok(art != null and art.global_position.distance_to(want) < 2.0,
		"the crop is drawn on its own cell (%s vs %s)" % [
			art.global_position if art != null else "no sprite", want])
	_ok(player.is_acting() and sprite.animation.begins_with("plant_"),
		"sowing crouches: %s" % sprite.animation)
	while player.is_acting():
		await physics_frame

	# --- a use that achieved nothing must not animate ----------------------
	# The hoe refuses to clear a plot with something growing in it, so the cat
	# must not mime a swing it never made.
	interactor.tool = Tools.HOE
	await physics_frame
	_use(interactor)
	await physics_frame
	_ok(farm.plots.has(cell), "the hoe refused to clear a growing plot")
	_ok(not player.is_acting(), "a refused use does not animate")

	# --- watering pours ----------------------------------------------------
	interactor.tool = Tools.CAN
	await physics_frame
	_use(interactor)
	await physics_frame
	_ok(farm.plots[cell].watered, "the plot got watered")
	_ok(player.is_acting() and sprite.animation.begins_with("water_"),
		"the can pours: %s" % sprite.animation)

	# --- walking away cancels it -------------------------------------------
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	_ok(not player.is_acting(), "walking away cancels the pour")
	Input.action_release("move_right")

	# --- picking it bends down ----------------------------------------------
	var clock := root.get_node("Clock")
	var crop: CropData = farm.plots[cell].crop
	var day := 2
	while not crop.is_ripe(farm.plots[cell].stage) and day < 30:
		farm.water(cell)
		clock.day_passed.emit(day)
		day += 1
	_ok(crop.is_ripe(farm.plots[cell].stage), "grew it to ripe")

	# Face south again - the cancel test above turned the cat east.
	Input.action_press("move_down")
	await physics_frame
	Input.action_release("move_down")
	for i in 4:
		await physics_frame
	player.global_position = water.to_global(water.map_to_local(centre + Vector2i(1, -6)))
	interactor.tool = Tools.HAND
	await physics_frame
	_use(interactor)
	await physics_frame
	_ok(player.is_acting() and sprite.animation.begins_with("harvest_"),
		"picking bends down: %s" % sprite.animation)

	quit(failures)
