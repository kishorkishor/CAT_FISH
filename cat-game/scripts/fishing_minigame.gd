extends CanvasLayer
## The fight. Hold anywhere to reel, release to give slack, keep the tension in
## the safe band until the fish is landed.
##
## One continuous analogue input on purpose: touch latency varies wildly across
## Android devices, and holding degrades gracefully where tapping to a rhythm
## does not. Grey rectangles for now - the yarn ball art replaces the bar, not
## the mechanic.
##
## Self-contained: takes a FishData in, emits caught or escaped, and knows
## nothing about the world, the player or the HUD.

signal caught(fish: FishData)
signal escaped

## Everything below is per-second and tuned live from the Inspector.
@export_group("Reeling")
## How fast holding raises tension.
@export var reel_rate := 0.9
## How fast releasing drops tension.
@export var slack_rate := 1.2
## How fast the fish is pulled in while the tension is in the safe band.
@export var reel_in_speed := 0.14
## How fast the fish drifts back out while the line is slack.
@export var drift_out_speed := 0.06

@export_group("Failure")
## Seconds the tension can sit above the band before the line snaps.
@export var fray_time := 1.2
## Seconds the line can sit fully slack before the fish tangles free.
@export var tangle_time := 2.5
## The fish escapes if it drifts back out to full distance.
@export var escape_distance := 1.0

var fish: FishData

var _tension := 0.3
var _distance := 0.7
var _fray := 0.0
var _tangle := 0.0
var _fought := 0.0
var _burst_left := 0.0
var _next_burst := 0.0
var _warning_left := 0.0
var _band_centre := 0.5
var _rng := RandomNumberGenerator.new()
var _resolved := false

@onready var _tension_fill: ColorRect = %TensionFill
@onready var _band: ColorRect = %SafeBand
@onready var _progress_fill: ColorRect = %ProgressFill
@onready var _warning: Label = %Warning
@onready var _title: Label = %Title
@onready var _yarn: AnimatedSprite2D = %Yarn


func start(data: FishData) -> void:
	fish = data
	_title.text = data.display_name
	_next_burst = _burst_gap()
	_band_centre = 0.5
	_layout_band()


func _process(delta: float) -> void:
	if fish == null or _resolved:
		return
	_fought += delta

	var holding := Input.is_action_pressed("reel")
	_tension += (reel_rate if holding else -slack_rate) * delta

	# Bursts: the fish yanks the line after a visible warning. Tired fish pull
	# at half strength once their stamina is spent.
	_update_burst(delta)
	if _burst_left > 0.0:
		var strength: float = fish.fight_strength * (0.5 if _fought > fish.stamina else 1.0)
		_tension += strength * delta
	_tension = clampf(_tension, 0.0, 1.0)

	var band: float = fish.safe_band_width + Game.rod.band_bonus
	var half: float = band * 0.5
	var in_band := absf(_tension - _band_centre) <= half

	if in_band and holding:
		_distance -= reel_in_speed * delta
	elif not holding:
		_distance += drift_out_speed * delta

	# Fraying is recoverable until it is not; same for the tangle at the bottom.
	_fray = _fray + delta if _tension > _band_centre + half else maxf(0.0, _fray - delta)
	_tangle = _tangle + delta if _tension <= 0.0 else 0.0

	if _distance <= 0.0:
		_resolve(true)
	elif _fray >= fray_time or _tangle >= tangle_time or _distance >= escape_distance:
		_resolve(false)

	_redraw(in_band)


func _update_burst(delta: float) -> void:
	if _burst_left > 0.0:
		_burst_left -= delta
		return
	if _warning_left > 0.0:
		_warning_left -= delta
		if _warning_left <= 0.0:
			_burst_left = 0.8
		return
	_next_burst -= delta
	if _next_burst <= 0.0:
		_warning_left = fish.burst_warning
		_next_burst = _burst_gap()


func _burst_gap() -> float:
	return _rng.randf_range(fish.burst_frequency * 0.6, fish.burst_frequency * 1.4)


func _resolve(landed: bool) -> void:
	_resolved = true
	if landed:
		caught.emit(fish)
		Events.fish_caught.emit(fish)
	else:
		escaped.emit()
		Events.fish_escaped.emit()
	queue_free()


func _layout_band() -> void:
	var track: ColorRect = %TensionTrack
	var h := track.size.y
	# The rod is what makes the band wider, so the upgrade is visible the
	# moment a fish is hooked rather than only in the numbers.
	var band: float = fish.safe_band_width + Game.rod.band_bonus
	_band.size.y = band * h
	_band.position.y = (1.0 - (_band_centre + band * 0.5)) * h


func _redraw(in_band: bool) -> void:
	var track: ColorRect = %TensionTrack
	var h := track.size.y
	_tension_fill.size.y = _tension * h
	_tension_fill.position.y = h - _tension_fill.size.y
	_tension_fill.color = Color(0.5, 0.9, 0.5) if in_band else Color(0.95, 0.55, 0.4)
	if _fray > 0.0:
		_tension_fill.color = Color(1.0, 0.3, 0.2)

	# The yarn ball rides the line: it climbs with tension and comes apart as the
	# line tightens, so the danger is legible without reading the bar.
	_yarn.position.y = (1.0 - _tension) * h
	var frames := _yarn.sprite_frames.get_frame_count(&"default")
	if frames > 0:
		_yarn.frame = clampi(int(_tension * frames), 0, frames - 1)
	_yarn.modulate = Color(1, 1, 1) if in_band else Color(1.0, 0.72, 0.62)

	_progress_fill.size.x = (1.0 - _distance) * %ProgressTrack.size.x
	_warning.visible = _warning_left > 0.0 or _burst_left > 0.0
	_warning.text = "!!" if _burst_left > 0.0 else "!"
