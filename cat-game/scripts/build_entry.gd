class_name BuildEntry
extends Resource
## One line in the build catalogue: what it is, what it costs, how much ground it
## takes. Anything already drawn as a prop scene becomes buildable by writing one
## of these - no new code.

@export var display_name := ""
@export var scene: PackedScene
@export var cost := 50
## Fraction of the cost handed back when it is taken down again.
@export_range(0.0, 1.0) var refund := 0.5
## Footprint in cells, width by depth. Most things are 1x1.
@export var size := Vector2i.ONE
## Piers and moorings go in the water; everything else wants dry land.
@export var on_water := false


## Every cell this occupies, relative to its anchor.
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in maxi(1, size.y):
		for x in maxi(1, size.x):
			out.append(Vector2i(x, y))
	return out
