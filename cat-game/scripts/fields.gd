extends Node2D
## The marked-out ground you are allowed to farm.
##
## Crops used to go anywhere the hoe reached, which made a farm a scatter of
## dots and made "where does my tool act" a question you had to answer by
## pressing and finding out. A field answers it before you press: inside the
## marked ground the tools work, outside they do not, and the boundary is drawn.
##
## Fields are rectangles in cell space. Cell space, not pixels, because the plots
## are keyed by cell and the two have to agree exactly - a field measured in
## pixels would sooner or later disagree with the plot sitting in it.

## Fill of marked ground, under the soil and over the grass.
const FIELD_FILL := Color(0.36, 0.28, 0.16, 0.35)
## The grid drawn on it. This is the thing that says "one plant per square".
const FIELD_GRID := Color(0.62, 0.54, 0.36, 0.5)
## Preview while you are marking one out.
const GHOST_OK := Color(0.45, 0.85, 0.45, 0.35)
const GHOST_BAD := Color(0.9, 0.4, 0.35, 0.35)

## Coins per cell to mark ground out. Fields are gated on coins and buildings on
## timber, so the two economies stay legible: fishing pays for farmland, felling
## pays for structures.
@export var cost_per_cell := 3
## Share of the cost returned when ground is given back to the grass.
@export_range(0.0, 1.0) var refund := 0.5
## Biggest a single field may be, in cells. Stops one press swallowing the island.
@export var max_side := 12

## Every marked rectangle, in cell coordinates.
var fields: Array[Rect2i] = []

## Set by the interactor while a field is being marked out.
var pending := Rect2i()
var pending_ok := false
var showing_pending := false

@onready var _ground: TileMapLayer = get_parent().get_node("Water")
@onready var _land: TileMapLayer = get_parent().get_node("Land")


## One field is already marked out by the cottage on a new game. The mechanic is
## shown before it is demanded, and the goal chain still asks you to till - which
## you can now do immediately instead of first learning a tool you have not met.
@export var starter_field := Rect2i(46, 52, 4, 8)


func _ready() -> void:
	Game.register_fields(self)
	if starter_field.get_area() > 0:
		fields.append(starter_field)
		queue_redraw()


# --- asking -----------------------------------------------------------------

func contains(cell: Vector2i) -> bool:
	for rect in fields:
		if rect.has_point(cell):
			return true
	return false


func field_at(cell: Vector2i) -> int:
	for i in fields.size():
		if fields[i].has_point(cell):
			return i
	return -1


## Rectangle between two corners, in the order they were pressed.
func between(a: Vector2i, b: Vector2i) -> Rect2i:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func cost_of(rect: Rect2i) -> int:
	return _new_cells(rect).size() * cost_per_cell


## Cells in the rectangle that are not already marked. Overlapping an existing
## field is allowed and simply cheaper, which is what makes growing one feel like
## extending it rather than paying twice for the same ground.
func _new_cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in rect.size.y:
		for x in rect.size.x:
			var cell := rect.position + Vector2i(x, y)
			if not contains(cell):
				out.append(cell)
	return out


## Why this rectangle cannot be marked out, or "" if it can.
func why_not(rect: Rect2i) -> String:
	if rect.size.x > max_side or rect.size.y > max_side * 2:
		return "too big - %d by %d cells at most" % [max_side, max_side * 2]
	var fresh := _new_cells(rect)
	if fresh.is_empty():
		return "that is already your field"
	for cell in fresh:
		# Cells are twice as wide as tall, so a field that reads square on screen
		# is twice as many cells deep as it is across. Nothing here has to know
		# that except the size limit above.
		if _ground.is_fully_secondary(cell) or _land._corner_mask(cell.x, cell.y) != 15:
			return "the whole field has to be on grass"
	var price := fresh.size() * cost_per_cell
	if Game.money < price:
		return "%d cells, %d coins - you have %d" % [fresh.size(), price, Game.money]
	return ""


func can_mark(rect: Rect2i) -> bool:
	return why_not(rect).is_empty()


# --- changing ----------------------------------------------------------------

func mark(rect: Rect2i) -> bool:
	if not can_mark(rect):
		return false
	var price := cost_of(rect)
	if not Game.spend(price):
		return false
	# Merged into whatever it touches rather than stacked on top, so a field that
	# has been grown three times is still one field to give back.
	var merged := rect
	for i in range(fields.size() - 1, -1, -1):
		if fields[i].intersects(Rect2i(merged.position - Vector2i.ONE,
				merged.size + Vector2i.ONE * 2)):
			merged = merged.merge(fields[i])
			fields.remove_at(i)
	fields.append(merged)
	queue_redraw()
	Events.field_marked.emit(merged)
	return true


## Hands a whole field back to the grass, with whatever is growing on it.
func clear_at(cell: Vector2i) -> bool:
	var index := field_at(cell)
	if index < 0:
		return false
	var rect := fields[index]
	var farm: Node2D = get_parent().get_node_or_null("Farm")
	if farm != null:
		for y in rect.size.y:
			for x in rect.size.x:
				var c := rect.position + Vector2i(x, y)
				if farm.plots.has(c):
					farm.plots[c].crop = null
					farm._refresh_sprite(farm.plots[c])
					farm.plots.erase(c)
		farm.queue_redraw()
	Game.earn(int(rect.get_area() * cost_per_cell * refund))
	fields.remove_at(index)
	queue_redraw()
	return true


# --- drawing -----------------------------------------------------------------

func _process(_delta: float) -> void:
	if showing_pending:
		queue_redraw()


func _draw() -> void:
	for rect in fields:
		for y in rect.size.y:
			for x in rect.size.x:
				_draw_cell(rect.position + Vector2i(x, y), FIELD_FILL, FIELD_GRID)
	if showing_pending:
		var tint := GHOST_OK if pending_ok else GHOST_BAD
		for y in pending.size.y:
			for x in pending.size.x:
				_draw_cell(pending.position + Vector2i(x, y), tint, tint)


## One cell of marked ground: a filled diamond with its edge drawn, which is what
## makes the grid read as squares you plant one thing in.
func _draw_cell(cell: Vector2i, fill: Color, edge: Color) -> void:
	var centre := to_local(_ground.to_global(_ground.map_to_local(cell)))
	var size := Vector2(_ground.tile_set.tile_size)
	var points := PackedVector2Array([
		centre + Vector2(-size.x * 0.5, 0), centre + Vector2(0, -size.y * 0.5),
		centre + Vector2(size.x * 0.5, 0), centre + Vector2(0, size.y * 0.5),
	])
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), edge, 1.0)


# --- saving ------------------------------------------------------------------

func to_save() -> Array:
	var out := []
	for rect in fields:
		out.append({"x": rect.position.x, "y": rect.position.y,
			"w": rect.size.x, "h": rect.size.y})
	return out


func from_save(data: Array) -> void:
	fields.clear()
	for row in data:
		fields.append(Rect2i(
			int(row.get("x", 0)), int(row.get("y", 0)),
			maxi(1, int(row.get("w", 1))), maxi(1, int(row.get("h", 1)))))
	queue_redraw()


## Saves written before fields existed have crops sitting on open grass. Rather
## than delete them, wrap what is there in fields so an old farm survives the
## change and simply arrives already marked out.
func adopt_orphans(cells: Array) -> void:
	for cell in cells:
		if contains(cell):
			continue
		fields.append(Rect2i(cell - Vector2i(1, 2), Vector2i(3, 5)))
	queue_redraw()
