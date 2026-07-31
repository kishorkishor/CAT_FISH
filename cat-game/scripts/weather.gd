extends Node
## What the sky is doing today.
##
## Weather earns its place by changing what you *do*, not just how things look:
## rain waters the whole farm overnight, so a wet week is a week you fish instead
## of hauling a can around, and a storm brings the deep-water fish closer in. A
## forecast that only tinted the screen would be wallpaper.

signal changed(kind: int)

enum Kind { CLEAR, CLOUDY, RAIN, STORM }

const NAMES := {
	Kind.CLEAR: "clear", Kind.CLOUDY: "cloudy", Kind.RAIN: "rain", Kind.STORM: "storm",
}

## Rolled per day. Weighted so most days are workable and a storm is an event.
const WEIGHTS := {Kind.CLEAR: 46, Kind.CLOUDY: 30, Kind.RAIN: 18, Kind.STORM: 6}

var kind: int = Kind.CLEAR

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Clock.day_passed.connect(func(_day): roll())
	roll()


func roll() -> void:
	var total := 0
	for weight in WEIGHTS.values():
		total += weight
	var pick := _rng.randi_range(1, total)
	for candidate in WEIGHTS:
		pick -= WEIGHTS[candidate]
		if pick <= 0:
			kind = candidate
			break
	changed.emit(kind)


func is_wet() -> bool:
	return kind == Kind.RAIN or kind == Kind.STORM


func name_of() -> String:
	return NAMES[kind]


## Multiplies the day's light. Overcast days are dimmer and bluer, and a storm is
## dark enough that the harbour lamp starts to matter.
func light_scale() -> Color:
	match kind:
		Kind.CLOUDY: return Color(0.86, 0.88, 0.94)
		Kind.RAIN: return Color(0.70, 0.76, 0.88)
		Kind.STORM: return Color(0.52, 0.58, 0.74)
	return Color.WHITE


## Storms push the deep-water fish inshore, so bad weather is worth going out in.
func depth_bonus() -> int:
	return 1 if kind == Kind.STORM else 0


func to_save() -> int:
	return kind


func from_save(value: int) -> void:
	kind = clampi(value, 0, Kind.size() - 1)
	changed.emit(kind)
