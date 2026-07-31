extends Control
## The front door.
##
## Boots into this rather than straight into the island, so there is somewhere to
## choose between carrying on and starting over - which the save system has
## supported for a while with no way to ask for it.
##
## The world scene is loaded rather than instanced here, so every probe that
## instantiates world.tscn directly keeps working unchanged.

const WORLD := "res://scenes/world.tscn"

@onready var _continue: Button = %Continue
@onready var _new: Button = %NewGame
@onready var _quit: Button = %Quit
@onready var _saved: Label = %SavedLine


func _ready() -> void:
	var has_save := FileAccess.file_exists(Game.SAVE_PATH)
	_continue.disabled = not has_save
	_saved.text = _describe_save() if has_save else "no voyage yet"
	(_continue if has_save else _new).grab_focus()

	_continue.pressed.connect(func(): _enter(true))
	_new.pressed.connect(func(): _enter(false))
	_quit.pressed.connect(func(): get_tree().quit())


## Peeks at the save without loading it, so the button can say what continuing
## would actually resume.
func _describe_save() -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return "a save from another version"
	return "day %d   ·   %d coins" % [int(parsed.get("day", 1)), int(parsed.get("money", 0))]


## Whether to resume is decided here and read by the world once it is up, so the
## world scene has no idea it was reached from a menu.
func _enter(resume: bool) -> void:
	Game.resume_on_load = resume
	if not resume:
		Game.wipe()
	get_tree().change_scene_to_file(WORLD)
