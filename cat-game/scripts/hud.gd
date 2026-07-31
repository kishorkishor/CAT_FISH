extends CanvasLayer
## Coins, bag, sell. Grey-box: labels and one button until real UI art exists.

@onready var _coins: Label = %Coins
@onready var _bag: Label = %Bag
@onready var _sell: Button = %Sell
@onready var _banner: Label = %Banner


func _ready() -> void:
	_sell.pressed.connect(func():
		Game.sell_all()
		_refresh())
	Events.fish_caught.connect(func(fish: FishData):
		_refresh()
		_flash("caught a %s!" % fish.display_name))
	Events.fish_escaped.connect(func(): _flash("it got away..."))
	Events.money_changed.connect(func(_total): _refresh())
	_refresh()


func _refresh() -> void:
	_coins.text = "coins: %d" % Game.money
	_bag.text = "bag: %d fish (%d)" % [Game.bag.size(), Game.bag_value()]
	_sell.disabled = Game.bag.is_empty()


func _flash(message: String) -> void:
	_banner.text = message
	_banner.visible = true
	_banner.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): _banner.visible = false)
