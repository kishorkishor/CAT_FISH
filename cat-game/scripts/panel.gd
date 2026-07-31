extends CanvasLayer
## Everything the cat knows, on one screen.
##
## The HUD only has room for coins and a bag count, which is fine while playing
## and useless when you want to know what you actually own, what is growing, and
## which key does what. This is that screen. It pauses the world while it is up,
## so reading it is never a race.

const ROW_HEIGHT := 34

@onready var _items: VBoxContainer = %Items
@onready var _crops: VBoxContainer = %Crops
@onready var _built: VBoxContainer = %Built
@onready var _title: Label = %PanelTitle
@onready var _wallet: Label = %Wallet

var _farm: Node2D = null
var _buildings: Node2D = null


func _ready() -> void:
	# Keep running while the tree is paused, otherwise the panel that did the
	# pausing cannot be closed again.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_farm = get_tree().get_first_node_in_group("farm")
	_buildings = get_tree().get_first_node_in_group("buildings")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("panel"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_rebuild()


func _rebuild() -> void:
	_title.text = "%s   -   %s" % ["Tides of Tuna", Clock.clock_text()]
	_wallet.text = "%d coins" % Game.money
	for box in [_items, _crops, _built]:
		for child in box.get_children():
			child.queue_free()

	# --- the bag, split so seeds do not hide among the produce -------------
	var produce := []
	var seeds := []
	for id in Game.bag:
		var item: ItemData = Game.items.get(id)
		if item == null:
			continue
		(seeds if item.plants != null else produce).append(item)
	produce.sort_custom(func(a, b): return a.value > b.value)
	seeds.sort_custom(func(a, b): return a.id < b.id)

	if produce.is_empty() and seeds.is_empty():
		_items.add_child(_note("the bag is empty"))
	for item in produce:
		_items.add_child(_row(item, "%d coins each" % item.value))
	if not seeds.is_empty():
		_items.add_child(_note("seeds"))
	for item in seeds:
		_items.add_child(_row(item, "sows %s" % item.plants.produce.display_name
			if item.plants != null and item.plants.produce != null else ""))

	# --- what is in the ground --------------------------------------------
	if _farm == null or _farm.plots.is_empty():
		_crops.add_child(_note("nothing planted yet - till some grass with the hoe"))
	else:
		var growing := {}
		var ripe := {}
		var bare := 0
		var dry := 0
		for key in _farm.plots:
			var plot = _farm.plots[key]
			if plot.crop == null:
				bare += 1
				continue
			var name: String = plot.crop.produce.display_name if plot.crop.produce != null else "crop"
			if plot.crop.is_ripe(plot.stage):
				ripe[name] = ripe.get(name, 0) + 1
			else:
				growing[name] = growing.get(name, 0) + 1
			if not plot.watered:
				dry += 1
		for name in ripe:
			_crops.add_child(_line("%d %s" % [ripe[name], name], "ready to pick"))
		for name in growing:
			_crops.add_child(_line("%d %s" % [growing[name], name], "still growing"))
		if bare > 0:
			_crops.add_child(_line("%d empty plot%s" % [bare, "" if bare == 1 else "s"], "plant something"))
		if dry > 0:
			_crops.add_child(_line("%d plot%s dry" % [dry, "" if dry == 1 else "s"], "no growth until watered"))

	# --- what has been built ----------------------------------------------
	if _buildings == null or _buildings.placed.is_empty():
		_built.add_child(_note("nothing built yet"))
	else:
		var counts := {}
		for p in _buildings.placed:
			counts[p.entry.display_name] = counts.get(p.entry.display_name, 0) + 1
		for name in counts:
			_built.add_child(_line("%d %s" % [counts[name], name], ""))


func _row(item: ItemData, note: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(40, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var name := Label.new()
	name.text = "%s x%d" % [item.display_name, Game.count_of(item.id)]
	name.custom_minimum_size.x = 210
	row.add_child(name)
	var right := Label.new()
	right.text = note
	right.modulate = Color(1, 1, 1, 0.55)
	row.add_child(right)
	return row


func _line(left: String, right: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 28
	var a := Label.new()
	a.text = left
	a.custom_minimum_size.x = 250
	row.add_child(a)
	var b := Label.new()
	b.text = right
	b.modulate = Color(1, 1, 1, 0.55)
	row.add_child(b)
	return row


func _note(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.5)
	return label
