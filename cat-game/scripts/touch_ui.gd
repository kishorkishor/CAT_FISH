extends CanvasLayer
## The on-screen controls, and the decision about whether to show them at all.
##
## Shown when the device has a touchscreen, hidden on desktop, and forceable
## either way from the Inspector so the layout can be checked without a phone.
## Every button pushes the same action the keyboard pushes, so there is exactly
## one code path for what a press means.

enum Show { AUTO, ALWAYS, NEVER }

@export var when: Show = Show.AUTO

@onready var _buttons: Control = %Buttons
@onready var _stick: Control = %Stick
@onready var _tool_icon: TextureRect = %TouchToolIcon


func _ready() -> void:
	visible = _wanted()
	if not visible:
		return
	# The reel button is a hold, not a tap: the fight is one continuous input and
	# that is the whole reason the mechanic survives a laggy phone.
	%Reel.button_down.connect(func(): Input.action_press("reel"))
	%Reel.button_up.connect(func(): Input.action_release("reel"))
	for spec in [["Use", "use"], ["Tool", "tool_next"], ["Cycle", "cycle"],
			["Jump", "jump"], ["Panel", "panel"]]:
		var button: BaseButton = get_node("%" + spec[0])
		var action: String = spec[1]
		button.pressed.connect(func(): _fire(action))
	var interactor := get_tree().get_first_node_in_group("interactor")
	if interactor != null:
		interactor.touch_mode = true
	Events.tool_changed.connect(_show_tool)
	_show_tool(Tools.HAND)


func _wanted() -> bool:
	match when:
		Show.ALWAYS: return true
		Show.NEVER: return false
	return DisplayServer.is_touchscreen_available()


## Buttons send an action rather than calling a method, so a touch press and a
## key press arrive at the same place and cannot drift apart.
func _fire(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _show_tool(tool: int) -> void:
	if Tools.ICONS.has(tool):
		_tool_icon.texture = load(Tools.ICONS[tool])
