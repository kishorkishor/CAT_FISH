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
## A pounce out of a run is flatter and quicker than a standing hop - the cat is
## already carrying speed, so it throws itself forward rather than upward.
@export var pounce_height: float = 12.0
## Seconds from leaving the ground to landing on a pounce.
@export var pounce_time: float = 0.34
## Allow steering while airborne.
@export var air_control: bool = true

@export_group("Sprites")
## Upright cat: idle, walk, jump.
@export var frames_upright: SpriteFrames
## Four-legged cat, used while running.
@export var frames_sprint: SpriteFrames
## The cat carrying its rod, used whenever the rod is the tool in paw. Same rig
## and canvas as the upright set, so it shares offset_upright.
@export var frames_rod: SpriteFrames
## Sprite offset that puts the upright cat's feet on the node origin.
@export var offset_upright := Vector2(0, -19)
## Same for the sprint set, which sits on its own canvas size.
@export var offset_sprint := Vector2(0, -16)

@export_group("Water")
## How far the sprite sinks while wading through shin-deep water.
@export var wade_sink: float = 3.0
## How far the sprite sinks while swimming, hiding the legs under the surface.
@export var swim_sink: float = 8.0
## How far it sinks out in deep water, where only head and shoulders show.
@export var deep_sink: float = 14.0
## Pixels per second while wading. Water drags, so this is under walk_speed.
@export var wade_speed: float = 95.0
## Pixels per second out in the deep, where the cat has less to push against.
@export var deep_speed: float = 70.0
## Where the water surface cuts the sprite, in node-local pixels. The node origin
## is the feet, which float at the surface while swimming, so 0 clips exactly
## there; negative values hide more of the body.
@export var waterline_y: float = 0.0
## The ripple only shows once the cat is actually moving, in squared px/s.
@export var ripple_min_speed_sq: float = 100.0
## Out in the deep the cat rides the swell. Peak of that rise and fall in pixels;
## the shallows get none of it, which is most of what tells the two apart once
## the waterline has eaten everything below the shoulders.
@export var swell_height: float = 2.5
## Full rise-and-fall cycles per second of the swell.
@export var swell_speed: float = 1.1
## Playback rate of the deep stroke. Under one because there is nothing underfoot
## to push against, so the cat hauls itself along slower than in the shallows.
@export var deep_anim_speed: float = 0.7
## How much wider the wake spreads in deep water than in the shallows.
@export var deep_ripple_scale: float = 1.35

@export_group("Isometric")
## Cells are twice as wide as they are tall. Without halving vertical movement,
## holding up crosses the island in half the time holding right does and the
## ground reads as sliding under you.
@export var iso_ratio: float = 0.5

## How deep the water under the cat is, set by the world each frame. Mirrors
## GroundBuilder.Depth: 0 land, 1 shallow, 2 mid, 3 deep.
var water_depth := 0

## True once the water is deep enough to swim in. Wading still counts as being on
## foot, so the cat can hop over a shallow puddle but not out of the open sea.
var in_water: bool:
	get: return water_depth >= 2
## Set by the interactor when the rod is the held tool, so the cat is drawn
## carrying it. Purely cosmetic; nothing about movement changes.
var holding_rod := false

## Set while something else owns the cat - casting a line, fighting a fish.
## Input is ignored but physics keeps running, so the cat glides to a stop.
var locked := false

## The swing, pour or crouch the cat is part-way through, and how long is left of
## it. A one-shot: it outranks standing still but not walking away, so a tool
## never traps you mid-animation.
var _action := ""
var _action_left := 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _shadow: Node2D = $Shadow
@onready var _ripple: AnimatedSprite2D = $Ripple

var _facing := "south"
var _jump_elapsed := -1.0
var _sprite_rest_y := 0.0
## Latched when the jump starts. A cat that leaves the ground on four legs has to
## land on four legs, so the rig cannot be re-decided from the run key mid-air.
var _pouncing := false
var _swell_phase := 0.0


func is_jumping() -> bool:
	return _jump_elapsed >= 0.0


func _ready() -> void:
	if frames_upright == null:
		frames_upright = _sprite.sprite_frames
	_sprite_rest_y = offset_upright.y


func facing() -> String:
	return _facing


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var state := _resolve_state(input)

	if not locked and Input.is_action_just_pressed("jump") and not is_jumping() and not in_water:
		_jump_elapsed = 0.0
		_pouncing = state == "run" and _has_pounce(_facing)
		state = "jump"

	_move(input, state, delta)
	_update_animation(input, state)
	_update_hop(delta)
	_update_swell(delta)
	_update_action(delta, input)


## Play the one-shot for a tool being used, facing whatever the cat is facing.
##
## The length is read off the animation rather than passed in, so retiming the
## art in the SpriteFrames retimes the cat without touching this file. An action
## with no art yet falls through the chain to idle and simply costs nothing.
func play_action(action: String) -> void:
	if in_water or is_jumping():
		return
	_action = action
	_action_left = 0.0
	var set := _set_for_action()
	if set == null:
		return
	var anim := _first_animation(set, _action_chain(action, _facing))
	if anim.is_empty() or anim.begins_with("idle_"):
		_action = ""
		return
	_action_left = float(set.get_frame_count(anim)) / maxf(1.0, set.get_animation_speed(anim))


func _update_action(delta: float, input: Vector2) -> void:
	if _action.is_empty():
		return
	# Walking away cancels it. A cat frozen through its own swing while you are
	# holding a direction reads as input being dropped.
	if input != Vector2.ZERO or in_water:
		_action = ""
		return
	_action_left -= delta
	if _action_left <= 0.0:
		_action = ""


func is_acting() -> bool:
	return not _action.is_empty()


func _set_for_action() -> SpriteFrames:
	if holding_rod and frames_rod != null:
		return frames_rod
	return frames_upright


## Every action falls back to the swing before it falls back to standing, so a
## new tool reads as *doing something* from the day it is added, and generating
## its own art later is a drop-in.
func _action_chain(action: String, direction: String) -> PackedStringArray:
	var chain := PackedStringArray(["%s_%s" % [action, direction]])
	match action:
		"build": chain.append("till_%s" % direction)
		"harvest": chain.append("plant_%s" % direction)
	chain.append("idle_%s" % direction)
	return chain


func _first_animation(set: SpriteFrames, chain: PackedStringArray) -> String:
	for candidate in chain:
		if set.has_animation(candidate):
			return candidate
	return ""


## A pounce needs the four-legged rig to actually have the frames for it,
## otherwise the cat would leap on all fours and land as a missing animation.
func _has_pounce(direction: String) -> bool:
	return frames_sprint != null and frames_sprint.has_animation("jump_%s" % direction)


## Swimming outranks everything: the cat cannot sprint or hop out of water.
## Wading does not - shin-deep water is still walking, just slower and wetter.
func _resolve_state(input: Vector2) -> String:
	if water_depth >= 3:
		return "deepswim"
	if water_depth == 2:
		return "swim"
	if is_jumping():
		return "jump"
	# A swing in progress beats standing still, and loses to walking away, which
	# _update_action has already cancelled by the time we get here.
	if is_acting():
		return _action
	if input == Vector2.ZERO:
		return "wade_idle" if water_depth == 1 else "idle"
	if water_depth == 1:
		return "wade"
	return "run" if Input.is_action_pressed("run") else "walk"


func _move(input: Vector2, state: String, delta: float) -> void:
	var steerable := air_control or not is_jumping()
	var target := Vector2.ZERO
	if steerable and input != Vector2.ZERO:
		var speed := walk_speed
		match state:
			"run": speed = run_speed
			"wade", "wade_idle": speed = wade_speed
			"swim": speed = swim_speed
			"deepswim": speed = deep_speed
			# A leap out of a sprint keeps the sprint's speed. Dropping to a walk
			# the moment the paws leave the ground reads as landing in treacle.
			"jump": speed = run_speed if _pouncing else walk_speed
		target = Vector2(input.x, input.y * iso_ratio) * speed

	var rate := acceleration if target != Vector2.ZERO else friction
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()


## A hop is cosmetic: the body never leaves the ground, only the sprite rises, so
## collisions and sorting keep working while the cat is in the air.
func _update_hop(delta: float) -> void:
	if not is_jumping():
		return
	var span := pounce_time if _pouncing else jump_time
	var peak := pounce_height if _pouncing else jump_height
	_jump_elapsed += delta
	if _jump_elapsed >= span:
		_jump_elapsed = -1.0
		_pouncing = false
		_sprite.offset.y = _sprite_rest_y
		return
	var t := _jump_elapsed / span
	_sprite.offset.y = _sprite_rest_y - peak * 4.0 * t * (1.0 - t)


## Out past the shelf the cat rides the swell. It is the one cue that survives the
## waterline clip - by the time the body is under, a rise and fall of a couple of
## pixels is most of what says this water is over the cat's head.
func _update_swell(delta: float) -> void:
	if is_jumping():
		return
	if water_depth < 3:
		_swell_phase = 0.0
		_sprite.offset.y = _sprite_rest_y
		return
	_swell_phase = fmod(_swell_phase + delta * swell_speed, 1.0)
	_sprite.offset.y = _sprite_rest_y + sin(_swell_phase * TAU) * swell_height


func _update_animation(input: Vector2, state: String) -> void:
	if input != Vector2.ZERO:
		_facing = _direction_name(input)

	var wanted_set := frames_upright
	if (state == "run" or _pouncing) and frames_sprint != null:
		wanted_set = frames_sprint
	elif holding_rod and frames_rod != null and water_depth < 2:
		# Dropped in deep water: the swim frames only exist on the upright set,
		# and a cat treading water is not carrying a rod anyway.
		wanted_set = frames_rod
	if wanted_set == null:
		return

	# Water sinks the sprite and the waterline shader erases whatever went under,
	# so one set of art covers every depth: wading shows the cat from the shins up,
	# swimming from the chest up, the open sea from the shoulders up. The ground
	# shadow goes as soon as there is water under the cat rather than ground.
	var base := offset_sprint if wanted_set == frames_sprint else offset_upright
	base.y += _sink_for(state)
	_shadow.visible = water_depth == 0
	_sprite.material.set_shader_parameter(&"clip_enabled", water_depth > 0)
	_sprite.material.set_shader_parameter(&"waterline_y", waterline_y)

	# A wake trails the cat only while it is actually moving through water, and it
	# spreads wider out in the deep where there is no bottom to break it up.
	_ripple.visible = water_depth > 0 and velocity.length_squared() > ripple_min_speed_sq
	_ripple.scale = Vector2.ONE * (deep_ripple_scale if water_depth >= 3 else 1.0)
	if _ripple.visible and not _ripple.is_playing():
		_ripple.play(&"default")

	if _sprite.sprite_frames != wanted_set or not is_equal_approx(_sprite_rest_y, base.y):
		_sprite.sprite_frames = wanted_set
		_sprite_rest_y = base.y
		_sprite.offset = base

	# Fall back down the chain rather than erroring, so a state whose animation has
	# not been generated yet still faces the right way instead of freezing. Wading
	# deliberately falls through to the walk cycle - the cat really is walking.
	var chain: PackedStringArray
	if state == _action and is_acting():
		chain = _action_chain(state, _facing)
	else:
		chain = PackedStringArray(["%s_%s" % [state, _facing]])
		match state:
			"wade": chain.append("walk_%s" % _facing)
			"wade_idle": chain.append("idle_%s" % _facing)
			"deepswim": chain.append("swim_%s" % _facing)
			# A pounce sits on the four-legged rig, which has a run cycle but no walk.
			"jump": chain.append("run_%s" % _facing)
		chain.append("walk_%s" % _facing)
		chain.append("idle_%s" % _facing)

	var wanted := _first_animation(wanted_set, chain)
	if wanted.is_empty():
		return
	_sprite.speed_scale = _rate_for(state, wanted_set, wanted)
	if _sprite.animation != wanted:
		_sprite.play(wanted)


## How fast to run the chosen animation.
##
## A jump is the interesting case: the arc is timed in seconds and the animation
## is timed in frames, and the two have no reason to agree. Left alone the cat
## lands halfway through its own leap, having never played the crouch it ends on,
## so the rate is stretched to fit whichever arc is in flight.
func _rate_for(state: String, set: SpriteFrames, anim: String) -> float:
	if state == "deepswim":
		# Nothing underfoot to push against, so the stroke is slower than in the
		# shallows. A difference in timing survives the waterline clip; by the
		# time the body is under, a difference in pose does not.
		return deep_anim_speed
	if state == "jump":
		var span := pounce_time if _pouncing else jump_time
		var fps := set.get_animation_speed(anim)
		var count := set.get_frame_count(anim)
		if span > 0.0 and fps > 0.0 and count > 0:
			return float(count) / (fps * span)
	return 1.0


func _sink_for(state: String) -> float:
	match state:
		"wade", "wade_idle": return wade_sink
		"swim": return swim_sink
		"deepswim": return deep_sink
	return 0.0


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
