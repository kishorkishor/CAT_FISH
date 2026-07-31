class_name ItemData
extends Resource
## Anything that can sit in the bag: a fish, a crop, a packet of seeds.
##
## One resource type for all of them, so the shop, the bag and the save file
## never need to know which kind of thing they are holding.

## Stable key used by the save file. Never rename one of these after shipping.
@export var id := ""
@export var display_name := ""
@export var icon: Texture2D
## What the shop pays for one.
@export var value := 1
## What the shop charges for one. 0 means it is not for sale.
@export var price := 0
## Planting this sows the crop it points at.
@export var plants: Resource
