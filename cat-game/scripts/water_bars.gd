extends Node2D
## Floating water meters over the plants that need one.
##
## Deliberately not over every plant. A farm of thirty healthy crops wearing
## thirty full bars is a wall of noise you learn to ignore, and the one plant in
## trouble disappears into it. A bar here means "this one wants you", so the eye
## goes straight to the row that matters.
##
## Drawn from one node above the farm rather than a child per plot: bars must sit
## on top of every plant regardless of y-sorting, and a plant is allowed to
## overlap the one behind it.

## Show a bar once the tank drops to this share.
@export var show_below := 0.55
## Bar size in pixels.
@export var bar_size := Vector2(20, 3)
## Gap between the top of the plant and its bar.
@export var lift := 6.0
## Used when a plant has no art to measure yet.
@export var fallback_height := 26.0

const EMPTY := Color(0.10, 0.10, 0.13, 0.75)
const FULL := Color(0.36, 0.68, 0.94)
const LOW := Color(0.94, 0.74, 0.30)
const DRY := Color(0.90, 0.35, 0.30)
const DEAD := Color(0.45, 0.42, 0.40)

@onready var _farm: Node2D = get_parent()
@onready var _ground: TileMapLayer = _farm.get_parent().get_node("Water")


func _ready() -> void:
	# Above the plants, which are y-sorted against each other inside the farm.
	z_index = 200
	z_as_relative = false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for key in _farm.plots:
		var plot = _farm.plots[key]
		if plot.crop == null:
			continue
		if not plot.dead and plot.water > show_below:
			continue

		var centre := to_local(_ground.to_global(_ground.map_to_local(plot.cell)))
		# Measured off the plant, not a fixed height. A sapling and a grown tree
		# are wildly different sizes, and one constant puts the bar either in the
		# foliage of the big one or floating in the sky above the small one.
		var height := fallback_height
		if plot.sprite != null and plot.sprite.texture != null:
			height = float(plot.sprite.texture.get_height())
		var top_left := centre + Vector2(-bar_size.x * 0.5, -height - lift - bar_size.y)
		draw_rect(Rect2(top_left, bar_size), EMPTY)

		if plot.dead:
			# A dead plant gets a flat grey bar rather than an empty one, so it
			# reads as "gone" instead of "water me and I will come back".
			draw_rect(Rect2(top_left, bar_size), DEAD)
			continue

		var filled: float = clampf(plot.water, 0.0, 1.0)
		if filled > 0.0:
			draw_rect(Rect2(top_left, Vector2(bar_size.x * filled, bar_size.y)),
				FULL if filled > 0.3 else LOW)
		else:
			# Bone dry and on the clock. The whole bar flashes so a wilting plant
			# is visible from across the farm rather than needing to be read.
			var pulse := 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.006)
			draw_rect(Rect2(top_left, bar_size), Color(DRY, pulse))
