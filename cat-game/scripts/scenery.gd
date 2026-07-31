@tool
extends Node2D
## One placed prop: a sprite whose base sits on the node origin so y-sorting
## against the cat just works, an optional collision circle so trunks are solid,
## and an optional bob for things floating on water.

## The prop art. The sprite is offset so the bottom-centre of the canvas lands
## on the node origin.
@export var texture: Texture2D:
	set(value):
		texture = value
		_apply()

## Animated props (swaying grass) set frames instead of texture; the looping
## "default" animation plays on its own.
@export var frames: SpriteFrames:
	set(value):
		frames = value
		_apply()

## Pixels between the canvas bottom edge and the prop's visual base - most art
## has a little transparent padding.
@export var base_pad := 2:
	set(value):
		base_pad = value
		_apply()

## Solid radius around the base. 0 is walk-through (bushes, grass tufts).
@export var collision_radius := 0.0:
	set(value):
		collision_radius = value
		_apply()

## Bob amplitude in pixels for floating props. 0 sits still.
@export var bob_amount := 0.0
@export var bob_speed := 1.6

var _sprite: Node2D
var _time := 0.0


func _ready() -> void:
	y_sort_enabled = true
	_apply()


func _process(delta: float) -> void:
	if bob_amount <= 0.0 or _sprite == null or Engine.is_editor_hint():
		return
	_time += delta
	_sprite.position.y = _base_offset().y + sin(_time * bob_speed * TAU) * bob_amount


func _apply() -> void:
	if not is_node_ready():
		return
	if _sprite != null:
		_sprite.queue_free()
	if frames != null:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.centered = false
		anim.autoplay = "default"
		_sprite = anim
	else:
		var still := Sprite2D.new()
		still.texture = texture
		still.centered = false
		_sprite = still
	add_child(_sprite)
	_sprite.position = _base_offset()

	for child in get_children():
		if child is StaticBody2D:
			child.queue_free()
	if collision_radius > 0.0 and not Engine.is_editor_hint():
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = collision_radius
		shape.shape = circle
		body.add_child(shape)
		add_child(body)


func _base_offset() -> Vector2:
	var size := Vector2.ZERO
	if frames != null and frames.get_frame_count("default") > 0:
		size = frames.get_frame_texture("default", 0).get_size()
	elif texture != null:
		size = texture.get_size()
	return Vector2(-size.x * 0.5, -size.y + base_pad)
