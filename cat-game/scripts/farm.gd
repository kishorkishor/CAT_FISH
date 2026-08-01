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
##
## Water is a level, not a flag. Every plant holds a tank that drains a little
## each day, and how fast depends on how big the plant has got: a seedling can be
## left for days, a grown tree drinks it dry overnight. Run the tank empty and
## the plant wilts - visibly, for a couple of days - before it finally dies, so
## neglect is a warning you can act on rather than an ambush.

const SOIL_COLOUR := Color(0.32, 0.22, 0.14)
const SOIL_WET := Color(0.20, 0.13, 0.09)
const SOIL_FED := Color(0.28, 0.19, 0.15)
const SOIL_FED_WET := Color(0.17, 0.11, 0.10)
## Grit in fed soil, light enough to read against both damp and dry.
const FLECK := Color(0.58, 0.45, 0.28)

## Below this the plant is thirsty enough to warn about.
const THIRSTY := 0.35

class Plot:
	var cell: Vector2i
	var crop: CropData = null
	var stage := 0
	var days_in_stage := 0
	## 0..1. Full means just watered.
	var water := 0.0
	## Consecutive days it has sat at zero.
	var wilt_days := 0
	var dead := false
	var fertilised := false
	var sprite: Sprite2D = null

	func thirsty() -> bool:
		return crop != null and not dead and water <= THIRSTY

	func wilting() -> bool:
		return crop != null and not dead and water <= 0.0

	## Whole days before it needs watering again. 0 means it needs it now.
	func days_left() -> int:
		if crop == null or dead:
			return 0
		return int(floor(water / crop.thirst(stage)))

var plots: Dictionary = {}

@onready var _ground: TileMapLayer = get_parent().get_node("Water")
@onready var _land: TileMapLayer = get_parent().get_node("Land")
@onready var _buildings: Node2D = get_parent().get_node("Buildings")


func _ready() -> void:
	y_sort_enabled = true
	Game.register_farm(self)
	Clock.day_passed.connect(_on_day_passed)


func _draw() -> void:
	# The soil is drawn rather than tiled: a tilled patch is a flat diamond on the
	# ground and needs no art, and drawing it here keeps it under every plant.
	for key in plots:
		var plot: Plot = plots[key]
		var centre := to_local(_ground.to_global(_ground.map_to_local(plot.cell)))
		var size := Vector2(_ground.tile_set.tile_size)
		var points := PackedVector2Array([
			centre + Vector2(-size.x * 0.5, 0), centre + Vector2(0, -size.y * 0.5),
			centre + Vector2(size.x * 0.5, 0), centre + Vector2(0, size.y * 0.5),
		])
		draw_colored_polygon(points, _soil_colour(plot))
		if plot.fertilised:
			_draw_flecks(centre, size)


## Damp soil is the darker version of whatever it already was, so watering and
## feeding stay separate facts rather than one four-way colour to memorise.
func _soil_colour(plot: Plot) -> Color:
	var wet: bool = plot.water > 0.0
	if plot.fertilised:
		return SOIL_FED_WET if wet else SOIL_FED
	return SOIL_WET if wet else SOIL_COLOUR


## Fed soil gets visible grit in it. Hue alone was the first attempt and it was
## unreadable at this size - two browns a few percent apart is not a signal, it
## is a memory test. Flecks you can see from across the farm.
func _draw_flecks(centre: Vector2, size: Vector2) -> void:
	const SPOTS: Array[Vector2] = [
		Vector2(-0.22, -0.06), Vector2(0.16, -0.14), Vector2(-0.04, 0.16),
		Vector2(0.26, 0.08), Vector2(-0.30, 0.10),
	]
	for spot in SPOTS:
		draw_rect(Rect2(centre + Vector2(spot.x * size.x, spot.y * size.y),
			Vector2(2, 2)), FLECK)


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
	plot.wilt_days = 0
	plot.dead = false
	# A seed goes into the ground damp. Sowing into dry soil and losing the plant
	# before you can fetch the can would be a gotcha, not a mechanic.
	plot.water = maxf(plot.water, 1.0)
	_refresh_sprite(plot)
	queue_redraw()
	Events.crop_planted.emit(crop)
	return true


## Fills the tank. Refuses only when it is already brimming, so topping up a
## half-empty plant is always allowed - waiting for it to run dry to "not waste"
## a watering would be exactly the wrong habit to teach.
func water(cell: Vector2i) -> bool:
	var plot: Plot = plots.get(cell)
	if plot == null or plot.water >= 1.0:
		return false
	plot.water = 1.0
	plot.wilt_days = 0
	_refresh_sprite(plot)
	queue_redraw()
	return true


## Fertiliser is a one-off per plot that speeds every stage while it lasts. It
## survives a harvest, so feeding a plot that regrows is worth more than feeding
## one that does not.
func fertilise(cell: Vector2i) -> bool:
	var plot: Plot = plots.get(cell)
	if plot == null or plot.fertilised:
		return false
	plot.fertilised = true
	queue_redraw()
	return true


## Returns how many were picked. 0 means there was nothing ready.
func harvest(cell: Vector2i) -> int:
	var plot: Plot = plots.get(cell)
	if plot == null or plot.crop == null or plot.dead or not plot.crop.is_ripe(plot.stage):
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
			if plot == null:
				return ""
			return "water" if plot.water < 1.0 else "already watered"
		Tools.HAND:
			if plot == null:
				return ""
			# Sowing used to be the one verb the game never advertised: stood on
			# bare soil with a pocket full of seed, the prompt went blank and the
			# only way to learn the paw plants things was to press and find out.
			if plot.crop == null:
				return "sow"
			if plot.dead:
				return "dead - clear it with the hoe"
			if plot.crop.is_ripe(plot.stage):
				return "harvest"
			return "still growing"
	return ""


## A plain-language readout of one plot: what is in it, how it is doing, and
## when it next wants water. This is the answer to "how am I supposed to know",
## so it says the number of days rather than hinting at it.
func describe(cell: Vector2i) -> String:
	var plot: Plot = plots.get(cell)
	if plot == null:
		return ""
	if plot.crop == null:
		return "bare soil - fed" if plot.fertilised else "bare soil"

	var name := _crop_name(plot.crop)
	if plot.dead:
		return "%s - dead" % name

	var state := "ripe" if plot.crop.is_ripe(plot.stage) else "growing"
	var thirst := ""
	if plot.wilting():
		var left: int = plot.crop.wilt_grace - plot.wilt_days + 1
		thirst = "WILTING - dies in %d day%s" % [left, "" if left == 1 else "s"]
	else:
		var days := plot.days_left()
		if days <= 0:
			thirst = "needs water today"
		else:
			thirst = "water in %d day%s" % [days, "" if days == 1 else "s"]

	var fed := " - fed" if plot.fertilised else ""
	return "%s, %s%s - %s" % [name, state, fed, thirst]


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
	# Rain fills every tank on the island, which is the whole reason to look at the
	# forecast: a wet week is a week you can spend fishing.
	var rained: bool = Weather.is_wet()
	for key in plots:
		var plot: Plot = plots[key]
		if rained or is_sprinkled(plot.cell):
			plot.water = 1.0
			plot.wilt_days = 0

		if plot.crop == null:
			plot.water = maxf(0.0, plot.water - 0.5)
			continue
		if plot.dead:
			continue

		# It grows on the water it had overnight, then drinks. Draining first
		# would mean a plant watered every single day still spent one day thirsty.
		if plot.water > 0.0:
			plot.wilt_days = 0
			var needed: int = plot.crop.days_to_leave(plot.stage)
			# Fed soil moves a plant along faster - that is what you paid for.
			plot.days_in_stage += 2 if plot.fertilised else 1
			if plot.days_in_stage >= needed and not plot.crop.is_ripe(plot.stage):
				plot.stage += 1
				plot.days_in_stage = 0
			plot.water = maxf(0.0, plot.water - plot.crop.thirst(plot.stage))
		else:
			# Bone dry: it wilts, and keeps wilting, until its grace runs out.
			plot.wilt_days += 1
			if plot.wilt_days > plot.crop.wilt_grace:
				plot.dead = true
				Events.notice.emit("a %s died of thirst" % _crop_name(plot.crop))
		_refresh_sprite(plot)
	queue_redraw()


## Whether a sprinkler reaches this cell.
##
## Distance is measured on screen with the vertical doubled, the same flattening
## every reach test in the game uses. Measuring in raw cell coordinates would
## make a sprinkler water a stripe four times wider than it is deep, because a
## cell is twice as wide as it is tall.
func is_sprinkled(cell: Vector2i) -> bool:
	if _buildings == null:
		return false
	var here := _ground.map_to_local(cell)
	for p in _buildings.placed:
		var radius: int = p.entry.waters_radius
		if radius <= 0:
			continue
		var d := here - _ground.map_to_local(p.cell)
		if Vector2(d.x, d.y * 2.0).length() <= float(radius) * _ground.tile_set.tile_size.x:
			return true
	return false


func _crop_name(crop: CropData) -> String:
	if crop != null and crop.produce != null:
		return crop.produce.display_name
	return "plant"


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
		plot.sprite.position = to_local(_ground.to_global(_ground.map_to_local(plot.cell)))
	var texture: Texture2D = plot.crop.stages[mini(plot.stage, plot.crop.stage_count() - 1)]
	plot.sprite.texture = texture
	if texture != null:
		# Bottom-centre on the cell centre, same rule every prop follows.
		plot.sprite.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
	# Colour carries the health, because there is no separate wilted or dead art
	# for five crops times four stages and inventing forty sprites to say "thirsty"
	# would be a poor trade against a tint that reads instantly.
	if plot.dead:
		plot.sprite.modulate = Color(0.42, 0.36, 0.30)
	elif plot.wilting():
		plot.sprite.modulate = Color(0.86, 0.68, 0.28)
	else:
		plot.sprite.modulate = Color.WHITE


# --- saving -----------------------------------------------------------------

func to_save() -> Array:
	var out := []
	for key in plots:
		var plot: Plot = plots[key]
		out.append({
			"x": plot.cell.x, "y": plot.cell.y,
			"crop": plot.crop.resource_path if plot.crop != null else "",
			"stage": plot.stage, "days": plot.days_in_stage,
			"water": plot.water, "wilt": plot.wilt_days,
			"dead": plot.dead, "fed": plot.fertilised,
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
		# Saves written before water was a level only recorded a yes/no. A plot
		# that was watered comes back with a full tank rather than an empty one.
		if entry.has("water"):
			plot.water = float(entry.get("water", 0.0))
		else:
			plot.water = 1.0 if bool(entry.get("watered", false)) else 0.0
		plot.wilt_days = int(entry.get("wilt", 0))
		plot.dead = bool(entry.get("dead", false))
		plot.fertilised = bool(entry.get("fed", false))
		plots[plot.cell] = plot
		_refresh_sprite(plot)
	queue_redraw()
