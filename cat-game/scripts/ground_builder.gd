@tool
extends TileMapLayer
## Builds an island out of any 16-tile corner set.
##
## Each cell picks its tile from which corners hold the primary terrain, masked as
## NW<<3 | NE<<2 | SW<<1 | SE, which lands at atlas coords (mask % 4, mask / 4).
## The primary terrain is always the landward one by convention, so this works for
## any set: grass_sand gives grass in sand, sand_water gives a sandbar in the sea.
##
## Corners sit on the lattice between cells, so cell (x, y) reads vertices (x, y),
## (x+1, y), (x, y+1) and (x+1, y+1). Deciding per vertex is what makes neighbouring
## cells agree on their shared edge.
##
## Runs in the editor as well as at runtime, so the island is visible and selectable
## on the canvas instead of appearing only on play. Turn off auto_build to stop it
## regenerating and paint the layer by hand.

const SOURCE_ID := 0
const COLS := 4

## Regenerate whenever a setting changes. Uncheck to hand-paint - the script will
## then leave whatever is on the layer alone.
@export var auto_build: bool = true:
	set(value):
		auto_build = value
		_refresh()

## Cells per side of the generated patch.
@export var grid_size: int = 22:
	set(value):
		grid_size = max(1, value)
		_refresh()

## Island radius in cells, measured from the centre of the patch.
@export var island_radius: float = 8.0:
	set(value):
		island_radius = value
		_refresh()

## Amplitude of the edge wobble, in cells. 0 gives a clean circle.
@export var edge_wobble: float = 1.6:
	set(value):
		edge_wobble = value
		_refresh()

## Vertical weight on the island shape. The stacked layout steps 64px across but
## only 16px down, so a circle in cell coordinates renders four times wider than
## tall. Weighting the vertical distance by 0.5 stretches the shape down the grid
## until it reads as the 2:1 ellipse a circle should be in isometric. 1.0 gives
## the old pancake.
@export var iso_ratio: float = 0.5:
	set(value):
		iso_ratio = clampf(value, 0.1, 1.0)
		_refresh()

## Leave cells with no primary terrain empty instead of filling them with the
## secondary. Set on an upper layer so the layer beneath shows through - that is
## what lets grass sit on sand which sits in water, from two 16-tile sets.
@export var skip_empty: bool = false:
	set(value):
		skip_empty = value
		_refresh()

@export_group("Bay")
## How far the bay bites into the coastline, in cells. 0 leaves the island whole.
@export var bay_depth: float = 0.0:
	set(value):
		bay_depth = max(0.0, value)
		_refresh()

## Compass direction of the harbour mouth, in degrees. 0 points along +X.
@export var bay_angle_deg: float = 25.0:
	set(value):
		bay_angle_deg = value
		_refresh()

## Radius of the carved bay circle, in cells.
@export var bay_radius: float = 6.0:
	set(value):
		bay_radius = max(0.0, value)
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	# Setters fire before the node is in the tree while a scene is loading.
	if not is_node_ready():
		return
	if auto_build:
		rebuild()


func rebuild() -> void:
	clear()
	if tile_set == null:
		return
	# An animated tileset keeps its fully-secondary tile on the appended animation
	# row rather than at (0,0); the tileset records where.
	var open_coords: Vector2i = tile_set.get_meta(&"open_coords", Vector2i(0, 0))
	for y in grid_size:
		for x in grid_size:
			var mask := _corner_mask(x, y)
			if mask == 0 and skip_empty:
				continue
			var coords := open_coords if mask == 0 else Vector2i(mask % COLS, mask / COLS)
			set_cell(Vector2i(x, y), SOURCE_ID, coords)


## True where none of the cell's corners are the primary terrain, i.e. the cell is
## entirely the second terrain the set was generated with. On the water layer that
## means open water with no sand in it.
func is_fully_secondary(cell: Vector2i) -> bool:
	return _corner_mask(cell.x, cell.y) == 0


func _corner_mask(x: int, y: int) -> int:
	var nw := 1 if _is_primary(x, y) else 0
	var ne := 1 if _is_primary(x + 1, y) else 0
	var sw := 1 if _is_primary(x, y + 1) else 0
	var se := 1 if _is_primary(x + 1, y + 1) else 0
	return (nw << 3) | (ne << 2) | (sw << 1) | se


## True where the vertex is inside the island. Deterministic on purpose - the same
## patch every run, so a rendering change is never confused with a new random island.
##
## The bay is a second circle subtracted from the first. Its centre sits at
## island_radius + bay_radius - bay_depth from the middle, so it always straddles
## the coastline: depth controls the bite without ever swallowing the centre.
func _is_primary(vx: int, vy: int) -> bool:
	var centre := grid_size * 0.5
	var v := Vector2(vx - centre, (vy - centre) * iso_ratio)
	var wobble := sin(vx * 0.9) * 0.5 + cos(vy * 0.7) * 0.5
	if v.length() + wobble * edge_wobble >= island_radius:
		return false
	if bay_depth > 0.0:
		var bay_centre := Vector2.from_angle(deg_to_rad(bay_angle_deg)) \
			* (island_radius + bay_radius - bay_depth)
		if v.distance_to(bay_centre) + wobble * edge_wobble < bay_radius:
			return false
	return true
