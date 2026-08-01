extends CanvasLayer
## The stall. Buy seeds and the next rod, sell everything else.
##
## Selling was already a button on the HUD; putting it here too is deliberate -
## the stall is where money is supposed to happen, and the loop reads better when
## the coins you just earned are on the same screen as the rod you want.

@onready var _rows: VBoxContainer = %Rows
@onready var _wallet: Label = %ShopWallet
@onready var _note: Label = %ShopNote


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("panel")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	get_tree().paused = true
	_rebuild()


func close() -> void:
	visible = false
	get_tree().paused = false


func _rebuild() -> void:
	_wallet.text = "%d coins" % Game.money
	for child in _rows.get_children():
		child.queue_free()

	# --- the rod ladder ----------------------------------------------------
	_rows.add_child(_heading("TACKLE"))
	var next: RodData = Game.next_rod()
	if next == null:
		_rows.add_child(_plain("you already hold the %s - nothing finer exists" % Game.rod.display_name))
	else:
		_rows.add_child(_offer(next.icon, next.display_name,
			"reaches %s water   ·   +%d%% safe band" % [
				["", "shallow", "mid", "deep"][next.max_depth], roundi(next.band_bonus * 100)],
			next.price, Game.money >= next.price,
			func():
				if Game.buy_rod(next):
					_flash("the %s is yours" % next.display_name)
					_rebuild()))

	# --- seeds and supplies -------------------------------------------------
	_rows.add_child(_heading("SEEDS AND SUPPLIES"))
	var seeds := []
	for id in Game.items:
		var item: ItemData = Game.items[id]
		if (item.plants != null or item.fertilises) and item.price > 0:
			seeds.append(item)
	seeds.sort_custom(func(a, b): return a.price < b.price)
	for item in seeds:
		var packet: ItemData = item
		_rows.add_child(_offer(packet.icon, packet.display_name,
			"you have %d" % Game.count_of(packet.id), packet.price,
			Game.money >= packet.price,
			func():
				if Game.spend(packet.price):
					Game.add_item(packet.id, 1)
					_rebuild()))

	# --- selling -----------------------------------------------------------
	_rows.add_child(_heading("YOUR CATCH AND CROP"))
	var worth := Game.bag_value()
	if worth <= 0:
		_rows.add_child(_plain("nothing to sell"))
	else:
		_rows.add_child(_offer(null, "sell everything", "%d items" % Game.sellable_count(),
			-worth, true,
			func():
				var earned := Game.sell_all()
				_flash("sold for %d coins" % earned)
				_rebuild()))


func _heading(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.62, 0.86, 0.86))
	return label


func _plain(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.55)
	return label


## One line: icon, name, a note, and a button whose label is the price. A
## negative price reads as money coming in rather than going out.
func _offer(icon: Texture2D, name: String, note: String, price: int,
		affordable: bool, on_press: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 44
	var art := TextureRect.new()
	art.texture = icon
	art.custom_minimum_size = Vector2(44, 40)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = name
	text.add_child(title)
	var sub := Label.new()
	sub.text = note
	sub.modulate = Color(1, 1, 1, 0.5)
	sub.add_theme_font_size_override("font_size", 15)
	text.add_child(sub)
	row.add_child(text)

	var button := Button.new()
	button.custom_minimum_size.x = 120
	button.text = ("+%d" % -price) if price < 0 else "%d" % price
	button.disabled = not affordable
	button.pressed.connect(on_press)
	row.add_child(button)
	return row


func _flash(message: String) -> void:
	_note.text = message
	_note.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(_note, "modulate:a", 0.0, 0.6)
