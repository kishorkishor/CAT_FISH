extends CharacterBody2D
## Eight-direction movement with walk, run, swim and a hop.
##
## Everything tunable is exported, so speeds, the hop and the sprite sets can be
## dialled in from the Inspector while the game is running rather than by editing
## this file.
##
## Running swaps to a whole different sprite set, because a cat on four legs is a
## separate rig rather than another animation of the upright one. The two sets sit
## on different canvas sizes, so each carries its own offset to keep the feet on
## the ground through the swap.

const DIRECTIONS: PackedStringArray = [
	"south", "south-west", "west", "north-west",
	"north", "north-east", "east", "south-east",
]

@export_group("Speed")
## Screen-space pixels per second while walking.
@export var walk_speed: float = 150.0
## Pixels per second while run is held.
@export var run_speed: float = 300.0
## Pixels per second in water.
@export var swim_speed: float = 90.0
## How quickly the cat reaches full speed. Lower is floatier.
@export var acceleration: float = 1800.0
## How quickly it stops once input ends.
@export var friction: float = 2200.0

@export_group("Hop")
## Peak height of the hop in pixels. The shadow stays on the ground.
@export var jump_height: float = 18.0
## Seconds from leaving the ground to landing.
@export var jump_time: float = 0.42
## Allow steering while airborne.
@export var air_control: bool = true

@export_group("Sprites")
## Upright cat: idle, walk, jump.
@export var frames_upright: SpriteFrames
## Four-legged cat, used while running.
@export var frames_sprint: SpriteFrames
## Sprite offset that puts the upright cat's feet on the node origin.
@export var offset_upright := Vector2(0, -19)
## Same for the sprint set, which sits on a larger canvas.
@export var offset_sprint := Vector2(0, -25)

@export_group("Isometric")
## Cells are twice as wide as they are tall. Without halving vertical movement,
## holding up crosses the island in half the time holding right does and the
## ground reads as sliding under you.
@export var iso_ratio: float = 0.5

## Set by the world when the cat is over water.
var in_water := false

@onready var _sprite: AnimatedSprite2D = $Sprite

var _facing := "south"
var _jump_elapsed := -1.0
var _sprite_rest_y := 0.0


func is_jumping() -> bool:
	return _jump_elapsed >= 0.0


func _ready() -> void:
	if frames_upright == null:
		frames_upright = _sprite.sprite_frames
	_sprite_rest_y = offset_upright.y


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var state := _resolve_state(input)

	if Input.is_action_just_pressed("jump") and not is_jumping() and not in_water:
		_jump_elapsed = 0.0
		state = "jump"

	_move(input, state, delta)
	_update_hop(delta)
	_update_animation(input, state)


## Swimming outranks everything: the cat cannot sprint or hop out of water.
func _resolve_state(input: Vector2) -> String:
	if in_water:
		return "swim"
	if is_jumping():
		return "jump"
	if input == Vector2.ZERO:
		return "idle"
	return "run" if Input.is_action_pressed("run") else "walk"


func _move(input: Vector2, state: String, delta: float) -> void:
	var steerable := air_control or not is_jumping()
	var target := Vector2.ZERO
	if steerable and input != Vector2.ZERO:
		var speed := walk_speed
		match state:
			"run": speed = run_speed
			"swim": speed = swim_speed
		target = Vector2(input.x, input.y * iso_ratio) * speed

	var rate := acceleration if target != Vector2.ZERO else friction
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()


## A hop is cosmetic: the body never leaves the ground, only the sprite rises, so
## collisions and sorting keep working while the cat is in the air.
func _update_hop(delta: float) -> void:
	if not is_jumping():
		return
	_jump_elapsed += delta
	if _jump_elapsed >= jump_time:
		_jump_elapsed = -1.0
		_sprite.offset.y = _sprite_rest_y
		return
	var t := _jump_elapsed / jump_time
	_sprite.offset.y = _sprite_rest_y - jump_height * 4.0 * t * (1.0 - t)


func _update_animation(input: Vector2, state: String) -> void:
	if input != Vector2.ZERO:
		_facing = _direction_name(input)

	var wanted_set := frames_sprint if state == "run" and frames_sprint != null else frames_upright
	if wanted_set == null:
		return
	if _sprite.sprite_frames != wanted_set:
		_sprite.sprite_frames = wanted_set
		_sprite_rest_y = (offset_sprint if wanted_set == frames_sprint else offset_upright).y
		_sprite.offset = Vector2((offset_sprint if wanted_set == frames_sprint else offset_upright).x, _sprite_rest_y)

	# Fall back down the chain rather than erroring, so a state whose animation has
	# not been generated yet still faces the right way instead of freezing.
	var wanted := ""
	for candidate in ["%s_%s" % [state, _facing], "walk_%s" % _facing, "idle_%s" % _facing]:
		if wanted_set.has_animation(candidate):
			wanted = candidate
			break
	if wanted.is_empty():
		return
	if _sprite.animation != wanted:
		_sprite.play(wanted)


## Screen-space input mapped to one of eight facings. The vertical axis is
## un-squashed first so a diagonal on the keyboard reads as a diagonal on the
## ground rather than being biased towards east and west.
##
## The angle is measured from south and increases towards west, which is the order
## DIRECTIONS is written in. Deriving it from angle_to() instead mirrors the result
## horizontally and hands back east for west.
func _direction_name(input: Vector2) -> String:
	var world := Vector2(input.x, input.y / iso_ratio)
	var angle := fposmod(atan2(-world.x, world.y), TAU)
	var index := int(round(angle / (TAU / DIRECTIONS.size()))) % DIRECTIONS.size()
	return DIRECTIONS[index]
