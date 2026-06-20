extends Node3D

@onready var door_body = $DoorBody
@onready var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")

var door_open = false
var tween: Tween
var player = null

func _ready():
	$SafeZoneTrigger.body_entered.connect(_on_safe_zone_entered)
	$SafeZoneTrigger.body_exited.connect(_on_safe_zone_exited)
	
	$DoorTrigger.body_entered.connect(_on_door_trigger_entered)
	$DoorTrigger.body_exited.connect(_on_door_trigger_exited)
	
	var tex = load("res://wall_texture.png")
	if tex:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.8, 0.8, 0.8, 1)
		mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
		mat.uv1_triplanar = false
		mat.roughness = 0.95
		$DoorBody/MeshInstance3D.material_override = mat

func _on_door_trigger_entered(body):
	if body.is_in_group("player"):
		open_door()

func _on_door_trigger_exited(body):
	if body.is_in_group("player"):
		close_door()

func _on_safe_zone_entered(body):
	if body.is_in_group("player"):
		body.is_safe = true
		if audio_manager and audio_manager.has_method("set_safe_mode"):
			audio_manager.set_safe_mode(true)

func _on_safe_zone_exited(body):
	if body.is_in_group("player"):
		body.is_safe = false
		if audio_manager and audio_manager.has_method("set_safe_mode"):
			audio_manager.set_safe_mode(false)

func open_door():
	if door_open: return
	door_open = true
	if audio_manager and audio_manager.has_method("play_door_open"):
		audio_manager.play_door_open()
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(door_body, "position:x", 3.8, 0.8).set_trans(Tween.TRANS_SINE)

func close_door():
	if not door_open: return
	door_open = false
	if audio_manager and audio_manager.has_method("play_door_close"):
		audio_manager.play_door_close()
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(door_body, "position:x", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
