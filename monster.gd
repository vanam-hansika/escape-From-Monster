extends CharacterBody3D

@export var base_speed: float = 4.5
@export var max_extra_speed: float = 3.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detector: Area3D = $Area3D

var player: CharacterBody3D = null
var current_speed: float = 3.0
var walk_time: float = 0.0

var current_state: String = "IDLE"
var last_known_pos: Vector3 = Vector3.ZERO

func _ready():
	add_to_group("monster")
	call_deferred("find_player")
	detector.body_entered.connect(_on_body_entered)
	set_physics_process(false) # Wait for navmesh to bake!
	
	var light = OmniLight3D.new()
	light.name = "MonsterLight"
	light.light_color = Color(1.0, 0.0, 0.0)
	light.light_energy = 5.0
	light.omni_range = 10.0
	light.position = Vector3(0, 1.5, 0)
	add_child(light)
	
	if has_node("MeshInstance3D"):
		get_node("MeshInstance3D").queue_free()
		
	# Load the requested custom devil image safely
	var tex = null
	var img = Image.new()
	if img.load("res://custom_devil.jpg") == OK:
		tex = ImageTexture.create_from_image(img)
		
	if tex:
		var mesh_inst = MeshInstance3D.new()
		var quad = QuadMesh.new()
		var aspect = float(tex.get_width()) / float(tex.get_height())
		quad.size = Vector2(2.6 * aspect, 2.6) # Slightly larger and more solid
		mesh_inst.mesh = quad
		mesh_inst.position = Vector3(0, 1.3, 0)
		
		# Custom shader to remove dark background
		var mat = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform sampler2D tex : source_color;

void fragment() {
	vec4 col = texture(tex, UV);
	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	// Very low threshold to not accidentally cut off dark parts of the monster
	if (luma < 0.02) {
		discard;
	} else {
		ALBEDO = col.rgb;
		
		// Add slight emission so it's never completely pitch black
		EMISSION = col.rgb * 0.15;
		
		// Realistic fleshy shading, removed fake normals to prevent half-black lighting issues
		ROUGHNESS = 0.6;
		METALLIC = 0.1;
	}
}
"""
		mat.shader = shader
		mat.set_shader_parameter("tex", tex)
		mesh_inst.material_override = mat
		add_child(mesh_inst)
		
	# Creepy dark trailing particles
	var particles = CPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 1.5
	particles.mesh = SphereMesh.new()
	particles.mesh.radius = 0.1
	particles.mesh.height = 0.2
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0, 0, 0, 0.6)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = pmat
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.2
	particles.gravity = Vector3(0, 1.5, 0)
	particles.position = Vector3(0, 1.0, 0)
	add_child(particles)

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta):
	if not player:
		find_player()
		return
		
	# Increase speed when player sanity is low
	var sanity_percent = 1.0
	if player.has_node("Sanity"):
		sanity_percent = player.get_node("Sanity").current_sanity / 100.0
	current_speed = base_speed + (1.0 - sanity_percent) * max_extra_speed
	
	# Trigger jumpscare if close enough (bulletproof)
	if not has_caught_player and not player.is_safe and global_position.distance_to(player.global_position) < 1.5:
		_on_body_entered(player)
		return
	
	if is_instance_valid(player):
		if player.is_safe:
			if current_state != "SEARCHING":
				current_state = "SEARCHING"
				# Walk far away from the safe room to prevent clipping/flickering through walls
				var rand_x = randf_range(10.0, 40.0)
				var rand_z = randf_range(10.0, 40.0)
				nav_agent.set_target_position(Vector3(rand_x, 0, rand_z))
		else:
			current_state = "CHASING"
			nav_agent.set_target_position(player.global_position)
			
		if has_node("MonsterLight"):
			var ml = get_node("MonsterLight")
			if current_state == "SEARCHING":
				ml.light_energy = lerp(ml.light_energy, 0.0, delta * 2.0)
			else:
				ml.light_energy = lerp(ml.light_energy, 5.0, delta * 2.0)
				
		var next_path_pos = nav_agent.get_next_path_position()
		
		var new_velocity = Vector3.ZERO
		var current_pos = global_position
		if global_position.distance_to(next_path_pos) > 0.1:
			new_velocity = (next_path_pos - current_pos).normalized() * current_speed
			new_velocity.y = 0 # keep monster on floor
				
		velocity = new_velocity
		
		# Gravity for monster
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		
		move_and_slide()
		
		# Procedural Walking Animation!
		if velocity.length() > 0.1:
			walk_time += delta * current_speed * 1.5
			if has_node("MeshInstance3D"):
				var mesh_inst = get_node("MeshInstance3D")
				# Bobbing up and down (footsteps)
				mesh_inst.position.y = 1.3 + abs(sin(walk_time)) * 0.15
				# Swaying side to side
				mesh_inst.rotation.z = sin(walk_time * 0.5) * 0.08
				# Aggressive lean forward
				mesh_inst.rotation.x = deg_to_rad(15.0)
				# Aggressive breathing
				mesh_inst.scale = Vector3(1.0, 1.0 + sin(walk_time * 2.0) * 0.03, 1.0)
		else:
			walk_time += delta * 2.0 # Idle breathing timer
			if has_node("MeshInstance3D"):
				var mesh_inst = get_node("MeshInstance3D")
				mesh_inst.position.y = lerp(mesh_inst.position.y, 1.3, delta * 5.0)
				mesh_inst.rotation.z = lerp(mesh_inst.rotation.z, 0.0, delta * 5.0)
				mesh_inst.rotation.x = lerp(mesh_inst.rotation.x, 0.0, delta * 5.0)
				mesh_inst.scale = Vector3(1.0 + sin(walk_time)*0.02, 1.0 + cos(walk_time)*0.02, 1.0)
		
		# Always face the player (manual billboarding) so the 2D image is visible
		var look_target = player.global_position
		look_target.y = global_position.y
		if global_position.distance_to(look_target) > 0.01:
			look_at(look_target, Vector3.UP)
			
		# QuadMesh faces +Z by default, but look_at points -Z at the player.
		# Rotate the mesh 180 degrees so the front of the image faces the player.
		if has_node("MeshInstance3D"):
			get_node("MeshInstance3D").rotation.y = PI
			
	# Cleanup old floaty animation block
	if has_node("Sprite3D"):
		get_node("Sprite3D").queue_free()

var has_caught_player = false

func _on_body_entered(body):
	if has_caught_player: return
	if body.is_in_group("player"):
		if body.is_safe: return
		
		# Prevent instant trigger if physics engine caught them overlapping at (0,0,0) before teleport
		if global_position.distance_to(body.global_position) > 2.0:
			return
			
		has_caught_player = true
		set_physics_process(false)
		
		call_deferred("_trigger_jumpscare", body)

func _trigger_jumpscare(body):
	# Teleport monster in front of camera safely
	var cam = body.get_node_or_null("CameraHead/Camera3D")
	if cam:
		var forward_dir = -cam.global_transform.basis.z
		forward_dir.y = 0.0
		if forward_dir.length_squared() < 0.01:
			forward_dir = Vector3(0, 0, 1)
		global_position = cam.global_position + forward_dir.normalized() * 1.5
		global_position.y = body.global_position.y
		
	var main = get_tree().current_scene
	if not main or not main.has_method("game_over_monster"):
		main = get_parent().get_parent()
		
	if main and main.has_method("game_over_monster"):
		main.game_over_monster()
