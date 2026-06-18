extends Control

signal joystick_vector_changed(vector: Vector2)

@export var max_length: float = 80.0
@export var deadzone: float = 0.15

var drag_position: Vector2 = Vector2.ZERO
var dragging: bool = false
var touch_id: int = -1

func _ready():
	custom_minimum_size = Vector2(200, 200)
	queue_redraw()

func _draw():
	var center = size / 2.0
	# Draw background circle
	draw_circle(center, max_length, Color(0.15, 0.15, 0.15, 0.45))
	draw_circle(center, max_length, Color(0.35, 0.35, 0.35, 0.3), false, 3.0)
	# Draw center knob
	draw_circle(center + drag_position, 28.0, Color(0.8, 0.8, 0.8, 0.6))

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			touch_id = event.index
			update_joystick(event.position - size / 2.0)
		elif event.index == touch_id:
			dragging = false
			touch_id = -1
			drag_position = Vector2.ZERO
			joystick_vector_changed.emit(Vector2.ZERO)
			queue_redraw()
			
	elif event is InputEventScreenDrag and dragging and event.index == touch_id:
		update_joystick(event.position - size / 2.0)

func update_joystick(local_pos: Vector2):
	if local_pos.length() > max_length:
		drag_position = local_pos.normalized() * max_length
	else:
		drag_position = local_pos
		
	var output_vector = drag_position / max_length
	if output_vector.length() < deadzone:
		output_vector = Vector2.ZERO
		
	joystick_vector_changed.emit(output_vector)
	queue_redraw()
