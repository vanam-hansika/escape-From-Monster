extends Node

@export var player_path: NodePath
@export var monster_path: NodePath

var player: CharacterBody3D
var monster: CharacterBody3D

var ambient_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var heartbeat_timer: float = 0.0

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
	
	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindPlayer"
	add_child(wind_player)
	
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.name = "HeartbeatPlayer"
	add_child(heartbeat_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)
	
	# Generate and set streams
	generate_audio_streams()
	
	# Start ambient sounds
	ambient_player.play()
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
		
	# Dynamic heartbeat speed based on distance
	var dist = player.global_position.distance_to(monster.global_position)
	
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
	
	sfx_player.stream = jumpscare_stream
	sfx_player.volume_db = 15.0
	sfx_player.play()

var jumpscare_stream: AudioStreamWAV

func generate_audio_streams():
	# Generate low drone for ambient
	ambient_player.stream = generate_drone(22050, 4.0)
	ambient_player.volume_db = -10.0
	
	# Generate wind noise
	wind_player.stream = generate_wind(22050, 3.0)
	wind_player.volume_db = -18.0
	
	# Generate heartbeat thump
	heartbeat_player.stream = generate_heartbeat(22050, 0.4)
	
	# Generate jumpscare scream
	jumpscare_stream = generate_screamer(22050, 1.5)

# Helper generators returning AudioStreamWAV

func generate_drone(mix_rate: int, duration: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(mix_rate * duration)
	
	var data = PackedByteArray()
	var total_samples = int(mix_rate * duration)
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		# Low frequency combination (drone)
		var val = sin(t * 55.0 * TAU) * 0.4 + sin(t * 82.0 * TAU) * 0.3 + sin(t * 110.0 * TAU) * 0.2
		# Creepy high-pitched dissonance (pulsating)
		val += sin(t * 880.0 * TAU) * 0.15 * sin(t * 0.5 * TAU)
		val += sin(t * 932.0 * TAU) * 0.15 * cos(t * 0.7 * TAU)
		# Add a bit of low-frequency noise
		val += (randf() - 0.5) * 0.1
		# Fade in/out at loop boundaries to avoid clicking
		var fade = 1.0
		if i < 1000:
			fade = float(i) / 1000.0
		elif i > total_samples - 1000:
			fade = float(total_samples - i) / 1000.0
		val *= fade
		
		var int_val = clampi(int(val * 32767.0), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
		
	stream.data = data
	return stream

func generate_wind(mix_rate: int, duration: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(mix_rate * duration)
	
	var data = PackedByteArray()
	var total_samples = int(mix_rate * duration)
	data.resize(total_samples * 2)
	
	var last_val = 0.0
	for i in range(total_samples):
		# Low-pass filtered noise for wind
		var noise = randf() - 0.5
		var val = last_val * 0.95 + noise * 0.05
		last_val = val
		# Dynamic wind gusting effect
		var t = float(i) / float(mix_rate)
		var gust = 0.5 + 0.5 * sin(t * 1.5 * TAU) * cos(t * 0.7 * TAU)
		val *= gust * 0.7
		
		# Fade at boundaries
		var fade = 1.0
		if i < 2000:
			fade = float(i) / 2000.0
		elif i > total_samples - 2000:
			fade = float(total_samples - i) / 2000.0
		val *= fade
		
		var int_val = clampi(int(val * 32767.0), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
		
	stream.data = data
	return stream

func generate_heartbeat(mix_rate: int, duration: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	
	var data = PackedByteArray()
	var total_samples = int(mix_rate * duration)
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var val = 0.0
		
		# Heartbeat thud: two distinct thuds close together
		# Thud 1 at t=0.0 to 0.12, Thud 2 at t=0.15 to 0.27
		if t < 0.12:
			var pulse_t = t / 0.12
			val = sin(pulse_t * PI) * sin(t * 60.0 * TAU) * exp(-pulse_t * 5.0)
		elif t > 0.15 and t < 0.27:
			var pulse_t = (t - 0.15) / 0.12
			val = sin(pulse_t * PI) * sin((t - 0.15) * 50.0 * TAU) * exp(-pulse_t * 5.0) * 0.8
			
		var int_val = clampi(int(val * 32767.0), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
		
	stream.data = data
	return stream

func generate_screamer(mix_rate: int, duration: float) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	
	var data = PackedByteArray()
	var total_samples = int(mix_rate * duration)
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		# Scream: Loud harsh saw wave mixed with high volume white noise, fading exponentially
		var wave = (fmod(t * 400.0, 1.0) - 0.5) * 0.4 + (fmod(t * 230.0, 1.0) - 0.5) * 0.3
		var noise = randf() - 0.5
		var val = wave + noise * 0.6
		
		# Exponential decay
		var decay = exp(-t * 2.5)
		val *= decay * 0.95
		
		var int_val = clampi(int(val * 32767.0), -32768, 32767)
		data[i * 2] = int_val & 0xFF
		data[i * 2 + 1] = (int_val >> 8) & 0xFF
		
	stream.data = data
	return stream
