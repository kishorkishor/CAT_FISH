extends CharacterBody2D
## The catamaran, once the cat is aboard.
##
## Boarding swaps which body the camera and the input drive: the cat is hidden
## and parked, the boat takes over, and stepping off puts the cat back on the
## nearest walkable ground. One camera, moved between the two, rather than two
## cameras fighting over the viewport.
##
## The boat is a boat, so it only goes where a boat goes - the shallows and out.
## Running it at the beach stops it dead rather than sailing it up the sand.

const DIRECTIONS: PackedStringArray = [
	"south", "south-west", "west", "north-west",
	"north", "north-east", "east", "south-east",
]

@export_group("Sailing")
## Top speed under sail, in screen pixels per second.
@export var speed := 190.0
## How quickly it gets there. Much lower than the cat: a boat has mass, and that
## weight is most of what makes sailing feel different from walking.
@export var acceleration := 260.0
## How quickly it slows when you let go.
@export var drag := 170.0
## Cells are twice as wide as they are tall.
@export var iso_ratio := 0.5
## Shallowest water it will float in. 1 is the wading shelf, 2 is swimmable.
@export var min_depth := 1

@export_group("Look")
@export var frames: SpriteFrames
@export var art_offset := Vector2(0, -54)
## Peak of the idle bob, in pixels.
@export var bob_height := 2.0
## Bobs per second.
@export var bob_speed := 0.6

## Set by the world each frame, same as the cat.
var water_depth := 0
var aboard := false

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _wake: AnimatedSprite2D = $Wake

var _facing := "south"
var _bob := 0.0


func _ready() -> void:
	visible = false
	set_physics_process(false)
	if frames != null:
		_sprite.sprite_frames = frames
	_sprite.offset = art_offset


func facing() -> String:
	return _facing


func board() -> void:
	aboard = true
	visible = true
	set_physics_process(true)
	velocity = Vector2.ZERO


func disembark() -> void:
	aboard = false
	set_physics_process(false)
	velocity = Vector2.ZERO
	# Left visible on purpose: the boat you got out of should still be there.
	visible = true


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := Vector2.ZERO
	if input != Vector2.ZERO:
		target = Vector2(input.x, input.y * iso_ratio) * speed
		_facing = _direction_name(input)

	var rate := acceleration if target != Vector2.ZERO else drag
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()

	_bob = fmod(_bob + delta * bob_speed, 1.0)
	_sprite.offset = art_offset + Vector2(0, sin(_bob * TAU) * bob_height)

	var anim := "sail_%s" % _facing
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim):
		if _sprite.animation != anim:
			_sprite.play(anim)

	_wake.visible = velocity.length_squared() > 400.0
	if _wake.visible and not _wake.is_playing():
		_wake.play(&"default")


## Same mapping the cat uses, so a direction means the same thing on deck as it
## does on foot.
func _direction_name(input: Vector2) -> String:
	var world := Vector2(input.x, input.y / iso_ratio)
	var angle := fposmod(atan2(-world.x, world.y), TAU)
	var index := int(round(angle / (TAU / DIRECTIONS.size()))) % DIRECTIONS.size()
	return DIRECTIONS[index]
