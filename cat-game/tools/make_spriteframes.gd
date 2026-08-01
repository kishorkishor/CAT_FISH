extends SceneTree
## Builds a SpriteFrames resource from a folder of character art.
##
##   godot --headless --path . --script res://tools/make_spriteframes.gd -- <name> [fps]
##
## Expects assets/characters/<name>/ laid out as:
##   rotations/<direction>.png          -> idle_<direction>, one frame
##   <animation>/<direction>/*.png      -> <animation>_<direction>, in filename order
##
## Any animation folder that appears is picked up, so adding a new one is a matter
## of dropping files in and re-running. Frames are plain PNGs rather than a packed
## sheet so a single frame can be repainted without unpacking anything.

const DIRECTIONS: PackedStringArray = [
	"south", "south-west", "west", "north-west",
	"north", "north-east", "east", "south-east",
]

## Animations that should not loop. A one-shot that loops reads as the cat having
## a fit rather than swinging a hoe once.
const ONCE: PackedStringArray = ["jump", "till", "water", "plant", "harvest", "build",
	"cast", "catch"]


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var name: String = argv[0] if argv.size() > 0 else "cat"
	var fps: float = float(argv[1]) if argv.size() > 1 else 10.0

	var base := "res://assets/characters/%s" % name
	if not DirAccess.dir_exists_absolute(base):
		push_error("no such character folder: %s" % base)
		quit(1)
		return

	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var added := 0
	for direction in DIRECTIONS:
		var still := "%s/rotations/%s.png" % [base, direction]
		if ResourceLoader.exists(still):
			_add(frames, "idle_%s" % direction, [still], fps, true)
			added += 1

	for anim in _subfolders(base):
		if anim == "rotations":
			continue
		for direction in DIRECTIONS:
			var dir_path := "%s/%s/%s" % [base, anim, direction]
			var paths := _pngs_in(dir_path)
			if paths.is_empty():
				continue
			_add(frames, "%s_%s" % [anim, direction], paths, fps, not ONCE.has(anim))
			added += 1

	if added == 0:
		push_error("found no frames under %s" % base)
		quit(1)
		return

	var out := "res://assets/characters/%s.tres" % name
	var err := ResourceSaver.save(frames, out)
	if err != OK:
		push_error("save failed: %d" % err)
		quit(1)
		return

	print("wrote %s (%d animations)" % [out, added])
	quit()


func _add(frames: SpriteFrames, anim: String, paths: Array, fps: float, loops: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loops)
	for path in paths:
		var texture: Texture2D = load(path)
		if texture != null:
			frames.add_frame(anim, texture)


func _subfolders(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for entry in dir.get_directories():
		out.append(entry)
	out.sort()
	return out


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
