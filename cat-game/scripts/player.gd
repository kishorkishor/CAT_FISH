extends CharacterBody2D
## Eight-direction movement with walk, run and a hop.
##
## Everything tunable is exported, so speeds, the hop and the run threshold can be
## dialled in from the Inspector while the game is running rather than by editing
## this file.

## Cardinal names in clockwise order starting at south, matching the order the
## sprite sheets are generated in.
const DIRECTIONS: PackedStringArray = [
	"south", "south-west", "west", "north-west",
	"north", "north-east", "east", "south-east",
]

@export_group("Speed")
## Screen-space pixels per second while walking.
@export var walk_speed: float = 150.0
## Pixels per second while run is held.
@export var run_speed: float = 300.0
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

@export_group("Isometric")
## Cells are twice as wide as they are tall. Without halving vertical movement,
## holding up crosses the island in half the time holding right does and the
## ground reads as sliding under you.
@export var iso_ratio: float = 0.5

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _shadow: Node2D = $Shadow

var _facing := "south"
var _jump_elapsed := -1.0
var _sprite_rest_y := 0.0


func is_jumping() -> bool:
	return _jump_elapsed >= 0.0


func _ready() -> void:
	_sprite_rest_y = _sprite.position.y


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := Input.is_action_pressed("run")

	if Input.is_action_just_pressed("jump") and not is_jumping():
		_jump_elapsed = 0.0

	_move(input, running, delta)
	_update_hop(delta)
	_update_animation(input, running)


func _move(input: Vector2, running: bool, delta: float) -> void:
	var steerable := air_control or not is_jumping()
	var target := Vector2.ZERO
	if steerable and input != Vector2.ZERO:
		target = Vector2(input.x, input.y * iso_ratio) * (run_speed if running else walk_speed)

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
		_sprite.position.y = _sprite_rest_y
		return
	# Parabola peaking at the halfway point.
	var t := _jump_elapsed / jump_time
	_sprite.position.y = _sprite_rest_y - jump_height * 4.0 * t * (1.0 - t)


func _update_animation(input: Vector2, running: bool) -> void:
	if input != Vector2.ZERO:
		_facing = _direction_name(input)

	var state := "idle"
	if is_jumping():
		state = "jump"
	elif input != Vector2.ZERO:
		state = "run" if running else "walk"

	var frames := _sprite.sprite_frames
	if frames == null:
		return

	# Fall back down the chain rather than erroring, so a character with only its
	# rotations generated still faces the right way while the animations are queued.
	var wanted := "%s_%s" % [state, _facing]
	for candidate in ["%s_%s" % [state, _facing], "walk_%s" % _facing, "idle_%s" % _facing]:
		if frames.has_animation(candidate):
			wanted = candidate
			break
	if not frames.has_animation(wanted):
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
