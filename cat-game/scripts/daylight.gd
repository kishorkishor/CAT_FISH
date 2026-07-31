extends CanvasModulate
## Dyes the whole world by the hour. One node, no per-sprite work, and it costs
## nothing - which is why the day cycle is worth having this early.

func _process(_delta: float) -> void:
	color = Clock.light_tint() * Weather.light_scale()
