extends Node2D
## The rain itself. Drawn rather than particle-simulated: a few hundred falling
## line segments cost almost nothing, tile forever, and never need an atlas.
##
## Sits on its own CanvasLayer so it stays put while the camera moves - rain
## falls on the screen, not on the world.

## Drops on screen at once, at full downpour.
@export var drop_count := 220
@export var fall_speed := 900.0
## How far the wind pushes the rain sideways, in pixels per second.
@export var slant := 190.0

var _drops: PackedVector2Array = []
var _speeds: PackedFloat32Array = []
var _strength := 0.0
var _size := Vector2(720, 1280)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_size = get_viewport_rect().size
	_seed()
	Weather.changed.connect(func(_k): set_process(true))
	set_process(true)


func _seed() -> void:
	_drops.clear()
	_speeds.clear()
	for i in drop_count:
		_drops.append(Vector2(_rng.randf_range(-_size.x * 0.4, _size.x * 1.2),
							  _rng.randf_range(0.0, _size.y)))
		_speeds.append(_rng.randf_range(0.75, 1.35))


func _process(delta: float) -> void:
	# Ease in and out so a shower starting or stopping is not a hard cut.
	var wanted := 0.0
	if Weather.kind == Weather.Kind.RAIN:
		wanted = 0.55
	elif Weather.kind == Weather.Kind.STORM:
		wanted = 1.0
	_strength = move_toward(_strength, wanted, delta * 0.6)
	if _strength <= 0.001:
		visible = false
		set_process(Weather.is_wet())
		return
	visible = true

	for i in _drops.size():
		var drop := _drops[i]
		drop.y += fall_speed * _speeds[i] * delta
		drop.x += slant * _speeds[i] * delta * (0.6 + _strength * 0.4)
		if drop.y > _size.y:
			drop.y = -20.0
			drop.x = _rng.randf_range(-_size.x * 0.4, _size.x * 1.2)
		_drops[i] = drop
	queue_redraw()


func _draw() -> void:
	var shown := int(_drops.size() * _strength)
	var colour := Color(0.78, 0.86, 0.95, 0.34 + _strength * 0.18)
	for i in shown:
		var drop := _drops[i]
		var tail := Vector2(-slant, -fall_speed).normalized() * (9.0 + _speeds[i] * 7.0)
		draw_line(drop, drop + tail, colour, 1.0)
