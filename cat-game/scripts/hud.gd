extends CanvasLayer
## Coins, bag, clock, the tool in paw, and a line telling the cat what the
## current tool would do to the ground it is facing.

@onready var _coins: Label = %Coins
@onready var _bag: Label = %Bag
@onready var _sell: Button = %Sell
@onready var _banner: Label = %Banner
@onready var _catch: TextureRect = %CatchPortrait
@onready var _clock: Label = %ClockLabel
@onready var _tool: Label = %ToolLabel
@onready var _prompt: Label = %Prompt

var _interactor: Node2D = null
var _farm: Node2D = null


func _ready() -> void:
	_interactor = get_tree().get_first_node_in_group("interactor")
	_farm = get_tree().get_first_node_in_group("farm")

	_sell.pressed.connect(func():
		var earned := Game.sell_all()
		_flash("sold the lot for %d coins" % earned if earned > 0 else "nothing to sell")
		_refresh())
	Events.fish_caught.connect(func(fish: FishData):
		_flash("caught a %s!" % fish.display_name, fish.sprite))
	Events.fish_escaped.connect(func(): _flash("it got away..."))
	Events.crop_harvested.connect(func(crop: CropData, count: int):
		var name := crop.produce.display_name if crop.produce != null else "crop"
		_flash("picked %d %s" % [count, name],
			crop.produce.icon if crop.produce != null else null))
	Events.money_changed.connect(func(_total): _refresh())
	Events.bag_changed.connect(_refresh)
	Events.notice.connect(func(message: String): _flash(message))
	Events.tool_changed.connect(func(_t): _refresh())
	_refresh()


func _process(_delta: float) -> void:
	_clock.text = Clock.clock_text()
	if _interactor == null or _farm == null:
		return
	# Say what the tool would do before it is used, so a miss is never a mystery.
	var action: String = _farm.action_at(_interactor.target_cell(), _interactor.tool)
	if _interactor.tool == Tools.BUILD:
		var entry: BuildEntry = _interactor.current_build()
		var reason: String = _interactor._buildings.why_not(_interactor.cursor_cell(), entry)
		_prompt.text = "%s - %s" % [entry.display_name, reason if reason else "place it"] \
			if entry != null else "nothing to build"
	elif _interactor.tool == Tools.ROD:
		_prompt.text = "cast into the water"
	elif action.is_empty():
		_prompt.text = ""
	else:
		_prompt.text = action


func _refresh() -> void:
	_coins.text = "coins: %d" % Game.money
	_bag.text = "bag: %d (%d)" % [Game.total_items(), Game.bag_value()]
	_sell.disabled = Game.bag_value() <= 0
	if _interactor != null:
		var extra := ""
		if _interactor.tool == Tools.HAND:
			var s: ItemData = _interactor.current_seed()
			extra = "  -  %s x%d" % [s.display_name, Game.count_of(s.id)] if s != null else "  -  no seeds"
		_tool.text = "%s%s" % [Tools.NAMES[_interactor.tool], extra]


func _flash(message: String, portrait: Texture2D = null) -> void:
	_banner.text = message
	_banner.visible = true
	_banner.modulate.a = 1.0
	_catch.texture = portrait
	_catch.visible = portrait != null
	_catch.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.set_parallel()
	tween.tween_property(_banner, "modulate:a", 0.0, 0.8)
	tween.tween_property(_catch, "modulate:a", 0.0, 0.8)
	tween.set_parallel(false)
	tween.tween_callback(func():
		_banner.visible = false
		_catch.visible = false)
