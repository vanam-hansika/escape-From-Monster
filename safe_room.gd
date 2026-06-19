extends Node3D

@onready var door_body = $DoorBody
@onready var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")

var door_open = false
var tween: Tween

var player_in_door_trigger = false
var player_in_safe_zone = false

func _ready():
	$DoorTrigger.body_entered.connect(_on_door_trigger_entered)
	$DoorTrigger.body_exited.connect(_on_door_trigger_exited)
	$SafeZoneTrigger.body_entered.connect(_on_safe_zone_entered)
	$SafeZoneTrigger.body_exited.connect(_on_safe_zone_exited)

func _on_door_trigger_entered(body):
	if body.is_in_group("player"):
		player_in_door_trigger = true
		update_door_state()

func _on_door_trigger_exited(body):
	if body.is_in_group("player"):
		player_in_door_trigger = false
		update_door_state()

func _on_safe_zone_entered(body):
	if body.is_in_group("player"):
		player_in_safe_zone = true
		body.is_safe = true
		if audio_manager and audio_manager.has_method("set_safe_mode"):
			audio_manager.set_safe_mode(true)
		update_door_state()

func _on_safe_zone_exited(body):
	if body.is_in_group("player"):
		player_in_safe_zone = false
		body.is_safe = false
		if audio_manager and audio_manager.has_method("set_safe_mode"):
			audio_manager.set_safe_mode(false)
		update_door_state()

func update_door_state():
	if player_in_safe_zone:
		# Player is inside the safe room, close the door!
		close_door()
	elif player_in_door_trigger:
		# Player is approaching or leaving (outside the safe zone but in trigger), open the door!
		open_door()
	else:
		# Player has left the area entirely, close the door!
		close_door()

func open_door():
	if door_open: return
	door_open = true
	if audio_manager and audio_manager.has_method("play_door_open"):
		audio_manager.play_door_open()
	if tween: tween.kill()
	tween = create_tween()
	# Slide the door to the side (X axis relative) to clear the opening
	tween.tween_property(door_body, "position:x", 3.8, 0.8).set_trans(Tween.TRANS_SINE)

func close_door():
	if not door_open: return
	door_open = false
	if audio_manager and audio_manager.has_method("play_door_close"):
		audio_manager.play_door_close()
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(door_body, "position:x", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
