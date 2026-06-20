extends Node

@export var player_path: NodePath
@export var monster_path: NodePath

var player: CharacterBody3D
var monster: CharacterBody3D

var ambient_player: AudioStreamPlayer
var safe_ambient_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var growl_player: AudioStreamPlayer

var heartbeat_timer: float = 0.0
var ambient_base_vol: float = -10.0

func _ready():
	# Locate player and monster
	if player_path:
		player = get_node(player_path)
	if monster_path:
		monster = get_node(monster_path)
		
	# Create audio players
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	add_child(ambient_player)

	safe_ambient_player = AudioStreamPlayer.new()
	safe_ambient_player.name = "SafeAmbientPlayer"
	add_child(safe_ambient_player)
	
	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindPlayer"
	add_child(wind_player)
	
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.name = "HeartbeatPlayer"
	add_child(heartbeat_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)
	
	growl_player = AudioStreamPlayer.new()
	growl_player.name = "GrowlPlayer"
	add_child(growl_player)
	
	# Defer stream generation so heavy processing runs AFTER scene loads completely
	# This prevents startup crashes on low-RAM Android devices
	call_deferred("generate_audio_streams")
	call_deferred("_start_ambient_after_load")

func _start_ambient_after_load():
	await get_tree().create_timer(0.3).timeout
	var ui = get_tree().current_scene.get_node_or_null("UI")
	if ui and ui.has_method("custom_log"): ui.custom_log("LOG: Ambient & wind start play requested")
	if ambient_player.stream:
		ambient_player.play()
	if wind_player.stream:
		wind_player.play()


func _physics_process(delta):
	# Fallbacks to find player and monster in groups
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	if not monster:
		var monsters = get_tree().get_nodes_in_group("monster")
		if monsters.size() > 0:
			monster = monsters[0]
			
	if not player or not monster:
		return
		
	# Handle monster chase sound fading
	var monster_is_chasing = false
	if is_instance_valid(monster) and "current_state" in monster:
		if monster.current_state == "CHASE" and is_instance_valid(player) and not player.is_safe:
			monster_is_chasing = true
			
	if monster_is_chasing:
		if not growl_player.playing:
			growl_player.play()
		growl_player.volume_db = lerp(growl_player.volume_db, 0.0, delta * 3.0)
	else:
		if growl_player.playing:
			growl_player.volume_db = lerp(growl_player.volume_db, -80.0, delta * 3.0)
			if growl_player.volume_db < -70.0:
				growl_player.stop()
		
	# Dynamic heartbeat speed based on distance
	var dist = player.global_position.distance_to(monster.global_position)
	
	# Calculate ambient music volume with monster proximity boost
	var target_ambient_vol = ambient_base_vol
	if ambient_base_vol > -40.0: # Only if not in safe room
		if dist < 20.0:
			var t_near = clamp(dist / 20.0, 0.0, 1.0)
			# volume goes from 5.0 dB (intense/loud) when right next to player, to -10.0 dB (normal) when far
			target_ambient_vol = lerp(5.0, -10.0, t_near)
	
	# Smoothly transition the ambient player volume
	ambient_player.volume_db = lerp(ambient_player.volume_db, target_ambient_vol, delta * 3.0)
	
	if dist > 35.0:
		# Too far, no heartbeat
		pass
	else:
		# Distance 0 to 35
		var t = clamp((dist - 3.0) / 32.0, 0.0, 1.0)
		var heartbeat_interval = lerp(0.45, 1.5, t)
		var volume = lerp(15.0, -5.0, t) # dB
		
		heartbeat_timer += delta
		if heartbeat_timer >= heartbeat_interval:
			heartbeat_timer = 0.0
			heartbeat_player.volume_db = volume
			heartbeat_player.play()

func play_jumpscare():
	# Stop background sounds and play loud jumpscare
	ambient_player.stop()
	wind_player.stop()
	heartbeat_player.stop()
	if growl_player:
		growl_player.stop()
	
	sfx_player.stream = jumpscare_stream
	sfx_player.volume_db = 15.0
	sfx_player.play()

func play_win():
	# Stop background sounds and play winning sound
	ambient_player.stop()
	wind_player.stop()
	heartbeat_player.stop()
	safe_ambient_player.stop()
	if growl_player:
		growl_player.stop()
		
	sfx_player.stream = win_stream
	sfx_player.volume_db = 5.0
	sfx_player.play()

var jumpscare_stream: AudioStream
var door_open_stream: AudioStream
var door_close_stream: AudioStream
var drink_stream: AudioStream
var win_stream: AudioStream

func generate_audio_streams():
	var ui = get_tree().current_scene.get_node_or_null("UI")
	if ui and ui.has_method("custom_log"): ui.custom_log("LOG: Loading audio streams...")
	
	ambient_player.stream = load("res://ambient_drone.wav")
	if ambient_player.stream:
		ambient_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambient_player.volume_db = -10.0
	if ui and ui.has_method("custom_log"): ui.custom_log("LOG: Ambient drone loaded and looping enabled")

	var peaceful_music_stream = load("res://peaceful music.mp3")
	if peaceful_music_stream:
		peaceful_music_stream.loop = true
		safe_ambient_player.stream = peaceful_music_stream
	safe_ambient_player.volume_db = -80.0
	
	var slide_door_s = load("res://sliding door opening sound.mp3")
	if slide_door_s:
		door_open_stream = slide_door_s
		door_close_stream = slide_door_s
		
	var growl_s = load("res://monster growl.mp3")
	if growl_s:
		growl_s.loop = true
		growl_player.stream = growl_s
		growl_player.volume_db = -80.0
		
	drink_stream = load("res://drink_sound.wav")
	
	var win_s = load("res://wiining sound.mp3")
	if win_s:
		win_stream = win_s
	
	wind_player.stream = load("res://wind_noise.wav")
	if wind_player.stream:
		wind_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wind_player.volume_db = -18.0
	if ui and ui.has_method("custom_log"): ui.custom_log("LOG: Wind noise loaded and looping enabled")
	
	heartbeat_player.stream = load("res://heartbeat.wav")
	
	jumpscare_stream = load("res://jumpscare_scream.wav")
	if ui and ui.has_method("custom_log"): ui.custom_log("LOG: All audio streams loaded successfully!")


func set_safe_mode(is_safe: bool):
	if is_safe:
		ambient_base_vol = -80.0
		create_tween().tween_property(wind_player, "volume_db", -80.0, 2.0)
		create_tween().tween_property(safe_ambient_player, "volume_db", -5.0, 2.0)
		safe_ambient_player.play()
	else:
		ambient_base_vol = -10.0
		create_tween().tween_property(wind_player, "volume_db", -18.0, 2.0)
		create_tween().tween_property(safe_ambient_player, "volume_db", -80.0, 2.0)

func play_door_open():
	sfx_player.stream = door_open_stream
	sfx_player.volume_db = 0.0
	sfx_player.play()

func play_door_close():
	sfx_player.stream = door_close_stream
	sfx_player.volume_db = 0.0
	sfx_player.play()

func play_drink():
	sfx_player.stream = drink_stream
	sfx_player.volume_db = 5.0
	sfx_player.play()


