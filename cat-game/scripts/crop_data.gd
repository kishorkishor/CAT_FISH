class_name CropData
extends Resource
## One thing that can be grown, described by its four stages.
##
## Stage art and stage timing live together so adding a crop is dropping in four
## PNGs and a .tres - no code, per the data-driven rule the project runs on.

## Four textures: sprouted, young, budding, ripe. The last one is harvestable.
@export var stages: Array[Texture2D] = []
## Days spent in each stage before moving to the next. Watered days only.
@export var days_per_stage: Array[int] = [1, 1, 1]
## What harvesting yields.
@export var produce: ItemData
## How many of it.
@export var yield_min := 1
@export var yield_max := 2
## Some plants keep bearing: harvesting drops them back to this stage instead of
## clearing the plot. -1 clears it.
@export var regrow_to := -1

@export_group("Thirst")
## How many days one watering lasts, per stage. A seedling can be left for days;
## a full-grown tree drinks it dry overnight. Shorter as the plant gets bigger is
## the whole point - a big farm of mature plants is what sprinklers are for.
@export var dry_days_per_stage: Array[int] = [3, 2, 2, 1]
## Days it can stand bone dry before it dies. It wilts visibly for all of them,
## so running dry is a warning rather than an ambush.
@export var wilt_grace := 2

@export_group("Timber")
## Whether the axe can fell this. Trees can; carrots cannot.
@export var is_tree := false
## Wood from felling it alive and healthy.
@export var wood_alive := 6
## Wood from felling it after it has died. Deliberately less: letting a tree die
## and then cashing it in should be the worse of the two choices.
@export var wood_dead := 2


func stage_count() -> int:
	return stages.size()


func is_ripe(stage: int) -> bool:
	return stage >= stages.size() - 1


## Days of watering needed to leave the given stage.
func days_to_leave(stage: int) -> int:
	if stage < days_per_stage.size():
		return maxi(1, days_per_stage[stage])
	return 1


## How many days a full tank lasts at this stage.
func dry_days(stage: int) -> int:
	if dry_days_per_stage.is_empty():
		return 2
	return maxi(1, dry_days_per_stage[mini(stage, dry_days_per_stage.size() - 1)])


## Share of the tank drunk in a day at this stage.
func thirst(stage: int) -> float:
	return 1.0 / float(dry_days(stage))
