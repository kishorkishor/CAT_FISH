extends SceneTree
## Captures the player mid-animation so a walk cycle can be checked without
## driving the game by hand.
##
##   godot --path . --resolution 540x960 --script res://tools/probe_anim.gd -- <scene> <anim> <out_dir>

const SETTLE := 10
const SHOTS := 6
const GAP := 4

var _player: Node2D = null
var _sprite: AnimatedSprite2D = null
var _anim := "walk_south"
var _out := "screenshots"
var _frames := 0
var _taken := 0


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var scene_path: String = argv[0] if argv.size() > 0 else "res://scenes/world.tscn"
	_anim = argv[1] if argv.size() > 1 else "walk_south"
	_out = argv[2] if argv.size() > 2 else "screenshots"

	var scene := (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	_player = scene.get_node("Entities/Player")
	_sprite = _player.get_node("Sprite")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE:
		return false
	if _sprite.animation != _anim:
		if not _sprite.sprite_frames.has_animation(_anim):
			print("no such animation: %s" % _anim)
			return true
		_sprite.play(_anim)
		return false
	if (_frames - SETTLE) % GAP != 0:
		return false

	var image := root.get_texture().get_image()
	var centre := Vector2i(image.get_width() / 2, image.get_height() / 2)
	image.get_region(Rect2i(centre.x - 45, centre.y - 70, 90, 90)).save_png(
		"%s/anim_%s_%d.png" % [_out, _anim, _taken])
	_taken += 1
	if _taken >= SHOTS:
		print("wrote %d frames of %s" % [SHOTS, _anim])
		return true
	return false
