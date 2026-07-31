extends SceneTree
## Drives the player with synthetic input and captures frames, so the sprite-set
## swap and animation states can be checked without playing by hand.
##
##   godot --path . --resolution 540x960 --script res://tools/probe_input.gd -- <scene> <actions> <out>
##
## <actions> is a plus-separated list, e.g. "move_right+run".

const SETTLE := 12
const SHOTS := 6
const GAP := 5

var _player: Node2D = null
var _sprite: AnimatedSprite2D = null
var _actions: PackedStringArray = []
var _out := "screenshots"
var _tag := "input"
var _frames := 0
var _taken := 0


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var scene_path: String = argv[0] if argv.size() > 0 else "res://scenes/test_ground.tscn"
	_tag = argv[1] if argv.size() > 1 else "move_right"
	_out = argv[2] if argv.size() > 2 else "screenshots"
	_actions = _tag.split("+")

	var scene := (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	_player = scene.get_node("Entities/Player")
	_sprite = _player.get_node("Sprite")


func _process(_delta: float) -> bool:
	_frames += 1
	for action in _actions:
		if InputMap.has_action(action):
			Input.action_press(action)
	if _frames < SETTLE:
		return false
	if (_frames - SETTLE) % GAP != 0:
		return false

	var image := root.get_texture().get_image()
	var centre := Vector2i(image.get_width() / 2, image.get_height() / 2)
	image.get_region(Rect2i(centre.x - 50, centre.y - 70, 100, 95)).save_png(
		"%s/in_%s_%d.png" % [_out, _tag, _taken])
	_taken += 1
	if _taken >= SHOTS:
		print("%s -> animation=%s frames=%d" % [
			_tag, _sprite.animation, _sprite.sprite_frames.get_frame_count(_sprite.animation)])
		return true
	return false
