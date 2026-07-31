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


func stage_count() -> int:
	return stages.size()


func is_ripe(stage: int) -> bool:
	return stage >= stages.size() - 1


## Days of watering needed to leave the given stage.
func days_to_leave(stage: int) -> int:
	if stage < days_per_stage.size():
		return maxi(1, days_per_stage[stage])
	return 1
