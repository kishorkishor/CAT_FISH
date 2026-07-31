class_name GoalData
extends Resource
## One rung of the opening. The game has a lot of verbs and, until now, nothing
## that says which one to try first - so a new player lands on an island holding
## five tools and no reason to use any of them.
##
## Goals are a chain, not a checklist: one is live at a time, each one teaches a
## verb, and the reward is the coins to afford the next thing worth doing.

@export var id := ""
## Shown as the objective line.
@export var title := ""
## The nudge underneath, saying where to go or which tool to hold.
@export var hint := ""
## What counts: caught, sold, planted, harvested, rod, built, slept.
@export_enum("caught", "sold", "planted", "harvested", "rod", "built", "slept") var track := "caught"
## How many of it. For "sold" this is coins earned, for "rod" it is the tier.
@export var target := 1
## Paid out on completion.
@export var reward := 0
