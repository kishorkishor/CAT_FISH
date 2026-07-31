extends Node
## Run state: the bag and the money. Listens to the bus rather than being called,
## so nothing needs a reference to it to add a catch.

var money := 0
var bag: Array[FishData] = []


func _ready() -> void:
	Events.fish_caught.connect(func(fish: FishData): bag.append(fish))


func bag_value() -> int:
	var total := 0
	for fish in bag:
		total += fish.value
	return total


func sell_all() -> void:
	if bag.is_empty():
		return
	money += bag_value()
	bag.clear()
	Events.money_changed.emit(money)
