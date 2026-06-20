extends Node3D

@onready var door_body = $DoorBody
@onready var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")

var door_open = false
var tween: Tween
var player = null

func _ready():
	$SafeZoneTrigger.body_entered.connect(_on_safe_zone_entered)
	$SafeZoneTrigger.body_exited.connect(_on_safe_zone_exited)
	
	var tex = load("res://wall_texture.png")
	if tex:
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.8, 0.8, 0.8, 1)
		mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
		mat.uv1_triplanar = false
		mat.roughness = 0.95
		$DoorBody/MeshInstance3D.material_override = mat

func _process(delta):
	if not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	if is_instance_valid(player):
		var door_global_pos = to_global(Vector3(0, 1.5, 2.0))
		var door_pos_2d = Vector2(door_global_pos.x, door_global_pos.z)
		var player_pos_2d = Vector2(player.global_position.x, player.global_position.z)
		
		var dist = player_pos_2d.distance_to(door_pos_2d)
		
		if dist < 1.9:
			open_door()
		else:
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
