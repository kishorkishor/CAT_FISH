extends Node
## The signal bus. Systems talk through here rather than holding references to
## each other, so the minigame does not know about the HUD and the HUD does not
## know about the world.

signal fish_hooked
signal fish_caught(fish: FishData)
signal fish_escaped
signal money_changed(total: int)
signal bag_changed
signal crop_harvested(crop: CropData, count: int)
signal tool_changed(tool: int)
signal rod_changed(rod: RodData)
signal crop_planted(crop: CropData)
signal sold(amount: int)
signal built(entry: BuildEntry)
signal slept
signal notice(message: String)
signal game_saved
