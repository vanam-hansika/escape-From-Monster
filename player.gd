extends CharacterBody3D

@export var walk_speed: float = 3.0
@export var sprint_speed: float = 5.5
@export var mouse_sensitivity: float = 0.002
@export var bob_freq: float = 2.4
@export var bob_amp: float = 0.08

var t_bob: float = 0.0
var gravity: float = 9.8

@onready var head: Node3D = $CameraHead
@onready var camera: Camera3D = $CameraHead/Camera3D
@onready var hand_container: Node3D = $CameraHead/Camera3D/HandContainer
@onready var stamina = $Stamina
@onready var sanity = $Sanity
@onready var flashlight = $CameraHead/Camera3D/HandContainer/WristRight/FistRight/FlashlightHandle/FlashlightHead/FlashlightSpotLight

var is_sprinting: bool = false
var speed: float = 3.0
var sway_target_rot := Vector3.ZERO
var can_move: bool = true

var mobile_movement_vector: Vector2 = Vector2.ZERO
var mobile_sprint_active: bool = false

var is_safe: bool = false
var drink_cooldown: float = 0.0

func can_drink() -> bool:
	return drink_cooldown <= 0.0

func start_drink_cooldown():
	drink_cooldown = 2.0

func drink_consumable():
	if stamina:
		stamina.current_stamina = stamina.max_stamina
	var audio = get_tree().current_scene.get_node_or_null("AudioManager")
	if audio and audio.has_method("play_drink"):
		audio.play_drink()

func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if has_node("CameraHead/Camera3D/HandContainer/WristLeft"):
		$CameraHead/Camera3D/HandContainer/WristLeft.hide()
		
	var flashlight = get_node_or_null("CameraHead/Camera3D/HandContainer/WristRight/FistRight/FlashlightHandle/FlashlightHead/FlashlightSpotLight")
	if flashlight:
		flashlight.shadow_bias = 0.05
		
	if flashlight:
		flashlight.shadow_bias = 0.15
		flashlight.shadow_normal_bias = 2.5
		
	# Setup InputMap actions programmatically
	var inputs = {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"toggle_flashlight": [KEY_F],
	}
	
	for action in inputs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
		for keycode in inputs[action]:
			var event = InputEventKey.new()
			event.keycode = keycode
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

func _unhandled_input(event):
	if not can_move:
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
		# Hand sway target calculation (more noticeable and smooth)
		sway_target_rot.y = clamp(-event.relative.x * 0.08, -0.4, 0.4)
		sway_target_rot.x = clamp(-event.relative.y * 0.08, -0.4, 0.4)

func _physics_process(delta):
	if drink_cooldown > 0.0:
		drink_cooldown -= delta

	if not can_move:
		return

	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Sprint
	is_sprinting = (Input.is_physical_key_pressed(KEY_SHIFT) or mobile_sprint_active) and is_on_floor() and stamina.current_stamina > 2.0
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if mobile_movement_vector != Vector2.ZERO:
		input_dir = mobile_movement_vector
		
	var is_moving = input_dir.length() > 0.0
	
	if is_sprinting and is_moving:
		speed = sprint_speed
		stamina.consume_stamina(delta * 1.5) # Fast drain
	elif is_moving:
		speed = walk_speed
		if not flashlight.is_on:
			stamina.recover_stamina(delta * 0.5) # Recover stamina while walking in the dark!
		else:
			stamina.consume_stamina(delta * 0.3) # Slow drain while walking with light
	else:
		speed = walk_speed
		if not flashlight.is_on:
			stamina.recover_stamina(delta * 2.0) # Fast recover in the dark
		else:
			stamina.recover_stamina(delta) # Recover when standing still
	
	# Direction of movement
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	# Camera Bobbing
	t_bob += delta * velocity.length() * float(is_on_floor())
	var bob_pos = _headbob(t_bob)
	
	# Shake effect based on sanity
	var shake_offset = Vector3.ZERO
	if sanity.current_sanity < 50.0:
		var shake_intensity = (50.0 - sanity.current_sanity) / 50.0 * 0.04
		shake_offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		
	camera.transform.origin = bob_pos + shake_offset
	
	# Hand Sway and Bobbing (highly noticeable and organic)
	if hand_container:
		hand_container.rotation.y = lerp(hand_container.rotation.y, sway_target_rot.y, delta * 4.0)
		hand_container.rotation.x = lerp(hand_container.rotation.x, sway_target_rot.x, delta * 4.0)
		sway_target_rot = lerp(sway_target_rot, Vector3.ZERO, delta * 4.0)
		
		# Hand bob position (scaled for walk vs sprint)
		var target_hand_pos = Vector3(0.0, -0.05, 0.0)
		if is_moving and is_on_floor():
			var multiplier = 1.8 if is_sprinting else 1.0
			target_hand_pos.y += sin(t_bob * 2.0) * 0.025 * multiplier
			target_hand_pos.x += cos(t_bob) * 0.015 * multiplier
		hand_container.position = lerp(hand_container.position, target_hand_pos, delta * 8.0)

	# Handle Flashlight Switch
	if Input.is_action_just_pressed("toggle_flashlight"):
		flashlight.toggle()

	# Monster proximity flickering
	var monsters = get_tree().get_nodes_in_group("monster")
	var is_monster_near = false
	var intensity = 0.0
	for m in monsters:
		if "current_state" in m and m.current_state != "IDLE":
			var dist = global_position.distance_to(m.global_position)
			if dist < 16.0:
				is_monster_near = true
				intensity = max(intensity, 1.0 - (dist / 16.0))
				
	if is_monster_near and flashlight.is_on:
		if randf() < intensity * 0.7:
			flashlight.light_energy = randf_range(0.0, flashlight.default_energy * 0.3)
		else:
			flashlight.light_energy = lerp(flashlight.light_energy, flashlight.default_energy, delta * 20.0)
	elif flashlight.is_on:
		flashlight.light_energy = lerp(flashlight.light_energy, flashlight.default_energy, delta * 5.0)

	# Safe Room Logic
	var was_safe = is_safe
	is_safe = false
	for sr in get_tree().get_nodes_in_group("safe_room"):
		if global_position.distance_to(sr.global_position) < 4.0:
			is_safe = true
			break
			
	if is_safe != was_safe:
		var am = get_tree().current_scene.get_node_or_null("AudioManager")
		if am and am.has_method("set_safe_mode"):
			am.set_safe_mode(is_safe)

	# Sanity logic (darkness check)
	var is_dark = not flashlight.is_on or flashlight.light_energy < flashlight.default_energy * 0.2
	sanity.update_sanity(delta, is_dark)

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp
	pos.x = cos(time * bob_freq / 2.0) * bob_amp
	return pos

func disable_movement():
	can_move = false
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func setup_gender(gender: String):
	var wrist_right = get_node_or_null("CameraHead/Camera3D/HandContainer/WristRight")
	var fist_right = get_node_or_null("CameraHead/Camera3D/HandContainer/WristRight/FistRight")
	
	if wrist_right:
		var mat = wrist_right.material_override
		if mat:
			var dup_mat = mat.duplicate() as StandardMaterial3D
			wrist_right.material_override = dup_mat
			if gender == "female":
				dup_mat.albedo_color = Color(0.85, 0.68, 0.6)
				wrist_right.scale = Vector3(0.75, 0.75, 0.9)
			else:
				dup_mat.albedo_color = Color(0.8, 0.6, 0.5)
				wrist_right.scale = Vector3(1.0, 1.0, 1.0)
				
	if fist_right:
		var mat = fist_right.material_override
		if mat:
			var dup_mat = mat.duplicate() as StandardMaterial3D
			fist_right.material_override = dup_mat
			if gender == "female":
				dup_mat.albedo_color = Color(0.85, 0.68, 0.6)
				fist_right.scale = Vector3(0.8, 0.8, 0.8)
			else:
				dup_mat.albedo_color = Color(0.8, 0.6, 0.5)
				fist_right.scale = Vector3(1.0, 1.0, 1.0)

