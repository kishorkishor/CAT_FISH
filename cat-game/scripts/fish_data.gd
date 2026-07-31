class_name FishData
extends Resource
## One fish. Five numbers give every fish its own fight without new mechanics:
## forty fish that all feel different, without writing forty systems.

## Shown in the log and the catch banner.
@export var display_name := "fish"
## 0 common .. 3 legendary. Scales value and, later, spawn weight.
@export_range(0, 3) var rarity := 0
## Coins when sold.
@export var value := 5
## Side-on portrait, shown when it is landed.
@export var sprite: Texture2D
## The bag entry this fish becomes once landed.
@export var item: ItemData

@export_group("Fight")
## How hard the fish pulls during a burst. Raises tension fast.
@export var fight_strength := 0.5
## Seconds of fighting before the fish tires and bursts weaken.
@export var stamina := 10.0
## Average seconds between bursts.
@export var burst_frequency := 3.0
## Seconds of warning shake before a burst hits.
@export var burst_warning := 0.6
## Fraction of the tension bar that is safe. Narrower is harder.
@export var safe_band_width := 0.35
