class_name RodData
extends Resource
## One rung of the rod ladder.
##
## A rod has to change fishing *visibly*, not just multiply a number, or the
## upgrade is a receipt rather than a reward. So each tier does two things you
## can see: it widens the safe band on the tension meter, and it reaches further
## out to sea - and the deep water is where the big fish are.

@export var id := ""
@export var display_name := ""
@export var icon: Texture2D
@export var price := 0
## Ladder position. The shop only offers the tier one above the one you hold.
@export var tier := 0

@export_group("Fishing")
## Added to every fish's safe band. Wider band, more forgiving fight.
@export var band_bonus := 0.0
## Deepest water this rod can cast into: 1 shallow, 2 mid, 3 deep.
## The fish that live out there are worth more, which is the whole point.
@export_range(1, 3) var max_depth := 1
## How far the line can be thrown, in cells.
@export var cast_range := 6
