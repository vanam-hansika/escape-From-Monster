extends Node

@export var player_path: NodePath
@export var monster_path: NodePath

var player: CharacterBody3D
var monster: CharacterBody3D

var safe_ambient_player: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var growl_player: AudioStreamPlayer

var ambient_base_vol: float = -10.0

func _ready():
	# Locate player and monster
	if player_path:
		player = get_node(player_path)
	if monster_path:
		monster = get_node(monster_path)
		
	# Create audio players
	safe_ambient_player = AudioStreamPlayer.new()
	safe_ambient_player.name = "SafeAmbientPlayer"
	add_child(safe_ambient_player)
	
	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "FootstepPlayer"
	add_child(footstep_player)
	
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.name = "HeartbeatPlayer"
	add_child(heartbeat_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)
	
	growl_player = AudioStreamPlayer.new()
	growl_player.name = "GrowlPlayer"
	add_child(growl_player)
	
	call_deferred("generate_audio_streams")

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
	
	# === MONSTER CHASE GROWL ===
	var monster_is_chasing = false
	if is_instance_valid(monster) and "current_state" in monster:
		if monster.current_state == "CHASE" and is_instance_valid(player) and not player.is_safe:
			monster_is_chasing = true
			
	if monster_is_chasing:
		if not growl_player.playing:
			growl_player.play()
		growl_player.volume_db = lerp(growl_player.volume_db, 0.0, delta * 3.0)
		# STOP footsteps and heartbeat during chase
		if footstep_player.playing:
			footstep_player.stop()
		if heartbeat_player.playing:
			heartbeat_player.stop()
	else:
		if growl_player.playing:
			growl_player.volume_db = lerp(growl_player.volume_db, -80.0, delta * 3.0)
			if growl_player.volume_db < -70.0:
				growl_player.stop()
	
	# === FOOTSTEP SOUND (only when walking, not during chase) ===
	if is_instance_valid(player) and not monster_is_chasing and not player.is_safe:
		var horizontal_vel = Vector2(player.velocity.x, player.velocity.z)
		var is_walking = horizontal_vel.length() > 0.5 and player.is_on_floor()
		
		if is_walking:
			if not footstep_player.playing:
				footstep_player.play()
			# Louder when sprinting
			if player.is_sprinting:
				footstep_player.volume_db = lerp(footstep_player.volume_db, 2.0, delta * 5.0)
			else:
				footstep_player.volume_db = lerp(footstep_player.volume_db, -5.0, delta * 5.0)
		else:
			if footstep_player.playing:
				footstep_player.stop()
	elif player.is_safe:
		if footstep_player.playing:
			footstep_player.stop()
	
	# === HEARTBEAT SOUND (when monster is nearby, not during chase) ===
	var dist = player.global_position.distance_to(monster.global_position)
	
	if not monster_is_chasing and not player.is_safe and dist < 25.0:
		if not heartbeat_player.playing:
			heartbeat_player.play()
		# Volume increases as monster gets closer (louder overall)
		var t = clamp(dist / 25.0, 0.0, 1.0)
		var target_vol = lerp(18.0, 0.0, t)
		heartbeat_player.volume_db = lerp(heartbeat_player.volume_db, target_vol, delta * 3.0)
		# Speed up playback when monster is very close
		var target_pitch = lerp(1.5, 0.8, t)
		heartbeat_player.pitch_scale = lerp(heartbeat_player.pitch_scale, target_pitch, delta * 3.0)
	else:
		if heartbeat_player.playing:
			heartbeat_player.volume_db = lerp(heartbeat_player.volume_db, -80.0, delta * 5.0)
			if heartbeat_player.volume_db < -70.0:
				heartbeat_player.stop()
				heartbeat_player.pitch_scale = 1.0

func play_jumpscare():
	# Stop everything and play jumpscare
	footstep_player.stop()
	heartbeat_player.stop()
	if growl_player:
		growl_player.stop()
	safe_ambient_player.stop()
	
	sfx_player.stream = jumpscare_stream
	sfx_player.volume_db = 15.0
	sfx_player.play()

func play_win():
	# Stop everything and play winning sound
	footstep_player.stop()
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
	# Footstep sound (looping)
	var footstep_s = load("res://foot_steps.mp3")
	if footstep_s:
		footstep_s.loop = true
		footstep_player.stream = footstep_s
		footstep_player.volume_db = -5.0

	# Peaceful music for safe room
	var peaceful_music_stream = load("res://peaceful music.mp3")
	if peaceful_music_stream:
		peaceful_music_stream.loop = true
		safe_ambient_player.stream = peaceful_music_stream
	safe_ambient_player.volume_db = -80.0
	
	# Door sounds
	var slide_door_s = load("res://sliding door opening sound.mp3")
	if slide_door_s:
		door_open_stream = slide_door_s
		door_close_stream = slide_door_s
		
	# Monster growl
	var growl_s = load("res://monster growl.mp3")
	if growl_s:
		growl_s.loop = true
		growl_player.stream = growl_s
		growl_player.volume_db = -80.0
	
	# Heartbeat sound (looping)
	var heartbeat_s = load("res://heartbeat.mp3")
	if heartbeat_s:
		heartbeat_s.loop = true
		heartbeat_player.stream = heartbeat_s
		heartbeat_player.volume_db = -80.0
		
	# Drink sound
	drink_stream = load("res://drink_sound.wav")
	
	# Win sound
	var win_s = load("res://wiining sound.mp3")
	if win_s:
		win_stream = win_s
	
	# Jumpscare scream
	jumpscare_stream = load("res://jumpscare_scream.wav")


func set_safe_mode(is_safe: bool):
	if is_safe:
		create_tween().tween_property(safe_ambient_player, "volume_db", -5.0, 2.0)
		safe_ambient_player.play()
	else:
		create_tween().tween_property(safe_ambient_player, "volume_db", -80.0, 2.0)

var _door_sound_cooldown: float = 0.0

func _process(delta):
	if _door_sound_cooldown > 0.0:
		_door_sound_cooldown -= delta

func play_door_open():
	if _door_sound_cooldown > 0.0:
		return
	_door_sound_cooldown = 1.5
	sfx_player.stream = door_open_stream
	sfx_player.volume_db = 0.0
	sfx_player.play()

func play_door_close():
	if _door_sound_cooldown > 0.0:
		return
	_door_sound_cooldown = 1.5
	sfx_player.stream = door_close_stream
	sfx_player.volume_db = 0.0
	sfx_player.play()

func play_drink():
	sfx_player.stream = drink_stream
	sfx_player.volume_db = 5.0
	sfx_player.play()
