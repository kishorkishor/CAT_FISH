class_name BaitData
extends Resource
## Something on the hook. Bait is the small decision that makes casting a choice
## rather than a reflex: it costs coins, it is consumed, and it changes the odds.

@export var id := ""
@export var display_name := ""
@export var icon: Texture2D
## Shifts the roll towards the rarer end. 0 is plain, 1 is heavily biased.
@export_range(0.0, 1.0) var richness := 0.0
## Reaches this many depth bands deeper than the rod alone could.
@export_range(0, 1) var depth_bonus := 0
