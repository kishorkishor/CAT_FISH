extends Node2D
## The float. A grey-box stand-in: a pale dot that dips when a fish bites.

var _biting := false


func bite() -> void:
	_biting = true
	queue_redraw()


func _draw() -> void:
	var y := 2.0 if _biting else 0.0
	draw_circle(Vector2(0, y), 3.0, Color(0.95, 0.9, 0.8))
	draw_circle(Vector2(0, y), 1.5, Color(0.85, 0.3, 0.25))
