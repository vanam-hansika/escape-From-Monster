extends Control

signal look_vector_changed(vector: Vector2)

var touch_id: int = -1
var dragging: bool = false

func _ready():
	# STOP so this control fully captures touch/drag events in its area
	mouse_filter = MOUSE_FILTER_STOP

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed and not dragging:
			dragging = true
			touch_id = event.index
		elif not event.pressed and event.index == touch_id:
			dragging = false
			touch_id = -1
			
	elif event is InputEventScreenDrag and dragging and event.index == touch_id:
		look_vector_changed.emit(event.relative)

# Reset state if the LookPad loses focus (e.g. coming back from objectives screen)
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		dragging = false
		touch_id = -1
