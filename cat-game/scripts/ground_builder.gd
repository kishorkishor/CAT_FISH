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
	for y in grid_size:
		for x in grid_size:
			var mask := _corner_mask(x, y)
			set_cell(Vector2i(x, y), SOURCE_ID, Vector2i(mask % COLS, mask / COLS))


func _corner_mask(x: int, y: int) -> int:
	var nw := 1 if _is_primary(x, y) else 0
	var ne := 1 if _is_primary(x + 1, y) else 0
	var sw := 1 if _is_primary(x, y + 1) else 0
	var se := 1 if _is_primary(x + 1, y + 1) else 0
	return (nw << 3) | (ne << 2) | (sw << 1) | se


## True where the vertex is inside the island. Deterministic on purpose - the same
## patch every run, so a rendering change is never confused with a new random island.
func _is_primary(vx: int, vy: int) -> bool:
	var centre := grid_size * 0.5
	var dist := Vector2(vx - centre, vy - centre).length()
	var wobble := sin(vx * 0.9) * 0.5 + cos(vy * 0.7) * 0.5
	return dist + wobble * edge_wobble < island_radius
