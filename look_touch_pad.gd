extends Control

signal look_vector_changed(vector: Vector2)

var touch_id: int = -1
var dragging: bool = false

func _ready():
	mouse_filter = MOUSE_FILTER_STOP

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			touch_id = event.index
		elif event.index == touch_id:
			dragging = false
			touch_id = -1
			
	elif event is InputEventScreenDrag and dragging and event.index == touch_id:
		look_vector_changed.emit(event.relative)
