@tool
extends Node2D
## One placed prop: a tree, a boat, a building.
##
## The node origin is where the prop meets the ground, and the art is lifted into
## place with the sprite's *offset* rather than its position. That distinction is
## the whole trick: y-sorting compares node positions, so a sprite moved up by its
## own height would sort by its treetop and never occlude anything standing
## behind it. Offsetting moves the pixels without moving the node, so a trunk
## sorts where the trunk actually is.
##
## The lift is measured from the art's opaque bounds, not its canvas, because
## generated art carries a different amount of transparent padding every time.
## Drop in a replacement texture and it seats itself on the ground.
##
## Runs in the editor, so a prop dragged into a scene looks in the editor exactly
## like it will in game.

## Nudge, in pixels, if the art's visual base is not where its opaque bounds end -
## a boat that should sit lower in the water, a post sunk into the sand.
@export var sink := 0:
	set(value):
		sink = value
		_align()

@export_group("Bob")
## Vertical drift in pixels, for things floating on water. 0 sits still.
@export var bob_amount := 0.0
## Full bob cycles per second.
@export var bob_speed := 0.6

var _rest := Vector2.ZERO
var _time := 0.0
var _aligned_to: Resource = null


func _ready() -> void:
	y_sort_enabled = true
	_align()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Only re-measure when the art itself changed, so swapping a texture in the
		# Inspector re-seats it without scanning an image every frame.
		var art := _art()
		if art != null and _source(art) != _aligned_to:
			_align()
		return
	if bob_amount <= 0.0:
		return
	_time += delta
	var art := _art()
	if art != null:
		art.offset = _rest + Vector2(0, sin(_time * bob_speed * TAU) * bob_amount)


## The Sprite2D or AnimatedSprite2D child holding the art, whichever this prop uses.
func _art() -> Node2D:
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null


func _source(art: Node2D) -> Resource:
	if art is Sprite2D:
		return art.texture
	if art is AnimatedSprite2D:
		return art.sprite_frames
	return null


func _align() -> void:
	if not is_node_ready():
		return
	var art := _art()
	if art == null:
		return
	var texture := _first_texture(art)
	if texture == null:
		return
	art.centered = false
	var bounds := _opaque_bounds(texture)
	# Bottom-centre of the opaque art lands on the node origin.
	_rest = Vector2(-(bounds.position.x + bounds.end.x) * 0.5, -bounds.end.y + sink)
	art.offset = _rest
	_aligned_to = _source(art)


func _first_texture(art: Node2D) -> Texture2D:
	if art is Sprite2D:
		return art.texture
	if art is AnimatedSprite2D and art.sprite_frames != null:
		var anim := &"default"
		if art.sprite_frames.has_animation(anim) and art.sprite_frames.get_frame_count(anim) > 0:
			return art.sprite_frames.get_frame_texture(anim, 0)
	return null


## Tightest rectangle containing every non-transparent pixel. Scanned once per
## texture; the art is small and the answer is cached by the caller.
func _opaque_bounds(texture: Texture2D) -> Rect2i:
	var image := texture.get_image()
	if image == null:
		return Rect2i(Vector2i.ZERO, texture.get_size())
	if image.is_compressed():
		image.decompress()
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var min_y := h
	var max_x := 0
	var max_y := 0
	for y in h:
		for x in w:
			if image.get_pixel(x, y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x + 1)
				max_y = maxi(max_y, y + 1)
	if min_x >= max_x:
		return Rect2i(Vector2i.ZERO, Vector2i(w, h))
	return Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)
