extends SceneTree
## Builds a SpriteFrames resource from a folder of effect frames.
##
##   godot --headless --path . --script res://tools/make_effect.gd -- <name> [fps]
##
## Expects assets/effects/<name>/frame_*.png and produces assets/effects/<name>.tres
## with a single looping "default" animation. Effects are one animation with no
## directions, which is why characters get make_spriteframes.gd and these do not.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var name: String = argv[0] if argv.size() > 0 else ""
	var fps: float = float(argv[1]) if argv.size() > 1 else 8.0

	if name.is_empty():
		push_error("usage: make_effect.gd -- <name> [fps]")
		quit(1)
		return

	var base := "res://assets/effects/%s" % name
	var paths := _pngs_in(base)
	if paths.is_empty():
		push_error("found no frames under %s" % base)
		quit(1)
		return

	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", true)
	for path in paths:
		var texture: Texture2D = load(path)
		if texture != null:
			frames.add_frame("default", texture)

	var out := "res://assets/effects/%s.tres" % name
	var err := ResourceSaver.save(frames, out)
	if err != OK:
		push_error("save failed: %d" % err)
		quit(1)
		return

	print("wrote %s (%d frames)" % [out, frames.get_frame_count("default")])
	quit()


## Sorted so frame order follows filename order rather than filesystem order.
func _pngs_in(path: String) -> Array:
	var out := []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	var names := PackedStringArray()
	for file in dir.get_files():
		if file.ends_with(".png"):
			names.append(file)
	names.sort()
	for file in names:
		out.append("%s/%s" % [path, file])
	return out
