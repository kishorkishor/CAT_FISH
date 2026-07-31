extends Node
## The calendar. Crops need something to grow against, so time is a real system
## rather than a timer bolted onto the farm.
##
## A day is short on purpose: this is a cozy game played in five minute sittings,
## and a crop that takes a real week to ripen is a crop nobody sees ripen.

signal day_passed(day: int)
signal hour_passed(hour: float)

## Real seconds in one in-game day.
const DAY_LENGTH := 240.0
## The hour the cat wakes up at, and the hour sleeping skips to.
const MORNING := 6.0

var day := 1
## 0..24. Starts in the morning rather than at midnight so a new game opens in daylight.
var hour := MORNING

var _last_hour := MORNING


func _process(delta: float) -> void:
	hour += delta * (24.0 / DAY_LENGTH)
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		day_passed.emit(day)
	if floorf(hour) != floorf(_last_hour):
		hour_passed.emit(hour)
	_last_hour = hour


## Skip to the next morning. Everything that ticks per-day still ticks, so
## sleeping through three days ripens three days of crops.
func sleep_until_morning() -> void:
	var target_day := day + 1
	while day < target_day:
		hour += 1.0
		if hour >= 24.0:
			hour -= 24.0
			day += 1
			day_passed.emit(day)
	hour = MORNING
	_last_hour = hour


func is_night() -> bool:
	return hour < 5.0 or hour >= 20.0


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	var suffix := "am" if h < 12 else "pm"
	var display := h % 12
	if display == 0:
		display = 12
	return "day %d  %d:%02d%s" % [day, display, m, suffix]


## Warm daylight, cool night, with dawn and dusk blended between. Returned as a
## tint for a CanvasModulate, which costs nothing and dyes the whole world at once.
func light_tint() -> Color:
	const NIGHT := Color(0.42, 0.48, 0.72)
	const DAY := Color(1.0, 1.0, 1.0)
	const DUSK := Color(1.0, 0.78, 0.62)
	if hour >= 5.0 and hour < 8.0:
		return NIGHT.lerp(DUSK, (hour - 5.0) / 3.0)
	if hour >= 8.0 and hour < 17.0:
		return DUSK.lerp(DAY, minf((hour - 8.0) / 2.0, 1.0))
	if hour >= 17.0 and hour < 20.0:
		return DAY.lerp(DUSK, (hour - 17.0) / 3.0)
	if hour >= 20.0 and hour < 22.0:
		return DUSK.lerp(NIGHT, (hour - 20.0) / 2.0)
	return NIGHT
