extends SceneTree
## Drives the game with simulated fingers: drag a thumbstick, hold the reel,
## tap the buttons. Asserts the touch path reaches exactly the same actions the
## keyboard does.

var failures := 0


func _ok(pass_: bool, message: String) -> void:
	print(("ok   " if pass_ else "FAIL ") + message)
	if not pass_:
		failures += 1


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	root.push_input(event)


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	root.push_input(event)


func _initialize() -> void:
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var touch: CanvasLayer = world.get_node("TouchUI")
	var stick: Control = touch.get_node("Stick")
	var player = world.get_node("Entities/Player")
	var interactor: Node2D = world.get_node("Interactor")

	# Force it on: the headless machine has no touchscreen, and the layout still
	# has to be testable without a phone.
	touch.when = touch.Show.ALWAYS
	touch._ready()
	await process_frame
	_ok(touch.visible, "the touch layer shows when forced on")
	_ok(interactor.touch_mode, "the interactor switched to aiming by facing")

	# --- the stick appears under the finger ---------------------------------
	var half := root.get_visible_rect().size.x * 0.5
	var origin := Vector2(half * 0.5, root.get_visible_rect().size.y * 0.7)
	_ok(not stick.visible, "the stick is invisible until touched")
	_touch(0, origin, true)
	await process_frame
	_ok(stick.visible, "it appears where the thumb landed")

	# --- dragging drives movement -------------------------------------------
	_drag(0, origin + Vector2(120, 0))
	await process_frame
	_ok(Input.is_action_pressed("move_right"), "dragging right presses move_right")
	_ok(not Input.is_action_pressed("move_left"), "and not the opposite")
	_ok(Input.get_action_strength("move_right") > 0.9,
		"a full-radius drag is full strength (%.2f)" % Input.get_action_strength("move_right"))

	var before: float = player.global_position.x
	for i in 20:
		await physics_frame
	_ok(player.global_position.x > before + 10.0,
		"the cat actually moved east (%.0fpx)" % (player.global_position.x - before))

	# --- a resting thumb does not creep --------------------------------------
	_drag(0, origin + Vector2(6, 0))
	await process_frame
	_ok(not Input.is_action_pressed("move_right"), "inside the dead zone nothing is pressed")

	# --- lifting releases everything -----------------------------------------
	_drag(0, origin + Vector2(0, -120))
	await process_frame
	_ok(Input.is_action_pressed("move_up"), "dragging up presses move_up")
	_touch(0, origin, false)
	await process_frame
	_ok(not stick.visible, "lifting hides the stick")
	var still_held := false
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_pressed(action):
			still_held = true
	_ok(not still_held, "and releases every direction")

	# --- the right half is not the stick -------------------------------------
	var right := Vector2(root.get_visible_rect().size.x * 0.8, origin.y)
	_touch(1, right, true)
	await process_frame
	_ok(not stick.visible, "touching the right half does not spawn a stick")
	_touch(1, right, false)

	# --- the reel button is a hold -------------------------------------------
	var reel: BaseButton = touch.get_node("Buttons/Reel")
	reel.button_down.emit()
	_ok(Input.is_action_pressed("reel"), "holding the reel button presses reel")
	reel.button_up.emit()
	_ok(not Input.is_action_pressed("reel"), "letting go releases it")

	# --- buttons fire the same actions the keys do ---------------------------
	var tool_before: int = interactor.tool
	touch.get_node("Buttons/Tool").pressed.emit()
	await process_frame
	_ok(interactor.tool != tool_before, "the tool button changed tool")

	var panel: CanvasLayer = world.get_node("Panel")
	touch.get_node("Buttons/Panel").pressed.emit()
	await process_frame
	_ok(panel.visible, "the bag button opened the panel")
	panel.toggle()

	quit(failures)
