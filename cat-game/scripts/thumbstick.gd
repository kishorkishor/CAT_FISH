extends Control
## A thumbstick that appears where the thumb lands.
##
## A stick painted in a fixed corner is a stick you have to look down at. This
## one is invisible until a finger touches its half of the screen, then draws
## itself under that finger - so the thumb never has to find it, and the same
## layout works on any phone size.
##
## It feeds the same move_* actions the keyboard uses, so nothing downstream
## knows or cares which one is driving.

## How far the finger has to travel for full speed, in pixels.
@export var radius := 90.0
## Movement under this fraction of the radius is ignored, so resting a thumb
## does not creep the cat across the island.
@export var dead_zone := 0.18

var _touch := -1
var _origin := Vector2.ZERO
var _current := Vector2.ZERO

const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]


func _ready() -> void:
	visible = false
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch < 0 and _mine(event.position):
			_touch = event.index
			_origin = event.position
			_current = event.position
			visible = true
			queue_redraw()
			_drive()
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		_current = event.position
		queue_redraw()
		_drive()


## Only the left half belongs to the stick; the right half is for buttons and
## for holding to reel.
func _mine(point: Vector2) -> bool:
	return point.x < get_viewport_rect().size.x * 0.5


func _release() -> void:
	_touch = -1
	visible = false
	queue_redraw()
	for action in ACTIONS:
		Input.action_release(action)


## Reported as four analogue actions rather than a vector, so the player script
## keeps its single Input.get_vector call and the keyboard path stays identical.
func _drive() -> void:
	var offset := _current - _origin
	var strength := clampf(offset.length() / radius, 0.0, 1.0)
	if strength < dead_zone:
		for action in ACTIONS:
			Input.action_release(action)
		return
	var dir := offset.normalized() * strength
	_press("move_right", dir.x)
	_press("move_left", -dir.x)
	_press("move_down", dir.y)
	_press("move_up", -dir.y)


func _press(action: String, amount: float) -> void:
	if amount > 0.0:
		Input.action_press(action, amount)
	else:
		Input.action_release(action)


func _draw() -> void:
	if _touch < 0:
		return
	var base := _origin - global_position
	var knob := _current - global_position
	var reach := knob - base
	if reach.length() > radius:
		knob = base + reach.normalized() * radius
	draw_circle(base, radius, Color(1, 1, 1, 0.10))
	draw_arc(base, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	draw_circle(knob, 26.0, Color(1, 1, 1, 0.30))
	draw_arc(knob, 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 2.0, true)
