extends Node2D
## The farm: every tilled plot on the island, keyed by cell.
##
## Plots are data in a dictionary, and each one owns a plain Sprite2D child for
## its plant. That is cheaper than a scene per plot and it keeps the plant inside
## the y-sorted Entities tree, so the cat walks in front of a short crop and
## behind a tall one without any extra work.
##
## Growth is counted in *watered days*, not elapsed days. A plot left dry simply
## does not advance, which is the whole reason the watering can exists.

const SOIL_COLOUR := Color(0.32, 0.22, 0.14)
const SOIL_WET := Color(0.20, 0.13, 0.09)

class Plot:
	var cell: Vector2i
	var crop: CropData = null
	var stage := 0
	var days_in_stage := 0
	var watered := false
	var sprite: Sprite2D = null

var plots: Dictionary = {}

@onready var _ground: TileMapLayer = get_parent().get_node("Water")
@onready var _land: TileMapLayer = get_parent().get_node("Land")


func _ready() -> void:
	y_sort_enabled = true
	Game.register_farm(self)
	Clock.day_passed.connect(_on_day_passed)


func _draw() -> void:
	# The soil is drawn rather than tiled: a tilled patch is a flat diamond on the
	# ground and needs no art, and drawing it here keeps it under every plant.
	for key in plots:
		var plot: Plot = plots[key]
		var centre := to_local(_ground.map_to_local(plot.cell))
		var size := Vector2(_ground.tile_set.tile_size)
		var points := PackedVector2Array([
			centre + Vector2(-size.x * 0.5, 0), centre + Vector2(0, -size.y * 0.5),
			centre + Vector2(size.x * 0.5, 0), centre + Vector2(0, size.y * 0.5),
		])
		draw_colored_polygon(points, SOIL_WET if plot.watered else SOIL_COLOUR)


# --- the four verbs ---------------------------------------------------------

## Ground can be tilled if it is dry land with nothing already on it.
func can_till(cell: Vector2i) -> bool:
	return not plots.has(cell) and not _ground.is_fully_secondary(cell) \
		and _land._corner_mask(cell.x, cell.y) == 15


func till(cell: Vector2i) -> bool:
	if not can_till(cell):
		return false
	var plot := Plot.new()
	plot.cell = cell
	plots[cell] = plot
	queue_redraw()
	return true


func plant(cell: Vector2i, crop: CropData) -> bool:
	var plot: Plot = plots.get(cell)
	if plot == null or plot.crop != null or crop == null:
		return false
	plot.crop = crop
	plot.stage = 0
	plot.days_in_stage = 0
	_refresh_sprite(plot)
	return true


func water(cell: Vector2i) -> bool:
	var plot: Plot = plots.get(cell)
	if plot == null or plot.watered:
		return false
	plot.watered = true
	queue_redraw()
	return true


## Returns how many were picked. 0 means there was nothing ready.
func harvest(cell: Vector2i) -> int:
	var plot: Plot = plots.get(cell)
	if plot == null or plot.crop == null or not plot.crop.is_ripe(plot.stage):
		return 0
	var crop := plot.crop
	var count := randi_range(crop.yield_min, crop.yield_max)
	if crop.produce != null:
		Game.add_item(crop.produce.id, count)
	Events.crop_harvested.emit(crop, count)

	if crop.regrow_to >= 0:
		# A plant that keeps bearing drops back a stage instead of dying, so a
		# strawberry patch is worth planting once and visiting often.
		plot.stage = crop.regrow_to
		plot.days_in_stage = 0
	else:
		plot.crop = null
		plot.stage = 0
	_refresh_sprite(plot)
	return count


## What the cat would do here, so the HUD can say so before the click.
func action_at(cell: Vector2i, tool: int) -> String:
	var plot: Plot = plots.get(cell)
	match tool:
		Tools.HOE:
			if plot != null and plot.crop == null:
				return "clear"
			return "till" if can_till(cell) else ""
		Tools.CAN:
			return "water" if plot != null and not plot.watered else ""
		Tools.HAND:
			if plot != null and plot.crop != null and plot.crop.is_ripe(plot.stage):
				return "harvest"
			return ""
	return ""


## The hoe doubles as an undo: it clears an empty plot back to grass.
func clear(cell: Vector2i) -> bool:
	var plot: Plot = plots.get(cell)
	if plot == null or plot.crop != null:
		return false
	if plot.sprite != null:
		plot.sprite.queue_free()
	plots.erase(cell)
	queue_redraw()
	return true


# --- growth -----------------------------------------------------------------

func _on_day_passed(_day: int) -> void:
	for key in plots:
		var plot: Plot = plots[key]
		if plot.crop != null and plot.watered:
			plot.days_in_stage += 1
			if plot.days_in_stage >= plot.crop.days_to_leave(plot.stage) \
					and not plot.crop.is_ripe(plot.stage):
				plot.stage += 1
				plot.days_in_stage = 0
				_refresh_sprite(plot)
		# Soil dries overnight. Growth is a habit, not a one-off.
		plot.watered = false
	queue_redraw()


func _refresh_sprite(plot: Plot) -> void:
	if plot.crop == null:
		if plot.sprite != null:
			plot.sprite.queue_free()
			plot.sprite = null
		return
	if plot.sprite == null:
		plot.sprite = Sprite2D.new()
		plot.sprite.centered = false
		add_child(plot.sprite)
		plot.sprite.position = to_local(_ground.map_to_local(plot.cell))
	var texture: Texture2D = plot.crop.stages[mini(plot.stage, plot.crop.stage_count() - 1)]
	plot.sprite.texture = texture
	if texture != null:
		# Bottom-centre on the cell centre, same rule every prop follows.
		plot.sprite.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())


# --- saving -----------------------------------------------------------------

func to_save() -> Array:
	var out := []
	for key in plots:
		var plot: Plot = plots[key]
		out.append({
			"x": plot.cell.x, "y": plot.cell.y,
			"crop": plot.crop.resource_path if plot.crop != null else "",
			"stage": plot.stage, "days": plot.days_in_stage, "watered": plot.watered,
		})
	return out


func from_save(data: Array) -> void:
	for key in plots.keys():
		clear(key)
	plots.clear()
	for entry in data:
		var plot := Plot.new()
		plot.cell = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var path: String = entry.get("crop", "")
		if not path.is_empty() and ResourceLoader.exists(path):
			plot.crop = load(path)
		plot.stage = int(entry.get("stage", 0))
		plot.days_in_stage = int(entry.get("days", 0))
		plot.watered = bool(entry.get("watered", false))
		plots[plot.cell] = plot
		_refresh_sprite(plot)
	queue_redraw()
