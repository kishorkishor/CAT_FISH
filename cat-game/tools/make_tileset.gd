extends SceneTree
## Builds an isometric TileSet from a packed atlas.
##
##   godot --headless --path . --script res://tools/make_tileset.gd -- <set_name>
##
## Geometry comes from the .json sidecar build_atlas.py writes, so regenerating
## tiles at a different size needs no change here. A script rather than a checked-in
## .tres so Godot assigns the resource UIDs itself.

const COLS := 4
const TILE_COUNT := 16


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var set_name: String = argv[0] if argv.size() > 0 else "grass_sand"

	var atlas_path := "res://assets/tiles/%s_atlas.png" % set_name
	var json_path := "res://assets/tiles/%s_atlas.json" % set_name
	var out_path := "res://assets/tiles/%s.tres" % set_name

	var geom := _read_geometry(json_path)
	if geom.is_empty():
		quit(1)
		return

	var texture: Texture2D = load(atlas_path)
	if texture == null:
		push_error("could not load %s" % atlas_path)
		quit(1)
		return

	var region := Vector2i(int(geom["tile_width"]), int(geom["tile_height"]))
	var cell := Vector2i(int(geom["cell_width"]), int(geom["cell_height"]))
	var origin := Vector2i(0, int(geom["texture_origin_y"]))

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = region
	for i in TILE_COUNT:
		var coords := Vector2i(i % COLS, i / COLS)
		source.create_tile(coords)
		source.get_tile_data(coords, 0).texture_origin = origin

	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_size = cell
	tile_set.add_source(source, 0)

	var err := ResourceSaver.save(tile_set, out_path)
	if err != OK:
		push_error("save failed: %d" % err)
		quit(1)
		return

	print("wrote %s (cell %s, region %s, origin %s)" % [out_path, cell, region, origin])
	quit()


func _read_geometry(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("missing %s - run tools/build_atlas.py first" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s is not valid JSON" % path)
		return {}
	return parsed
