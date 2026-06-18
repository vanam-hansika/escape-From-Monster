extends Node3D

@onready var detector: Area3D = $Area3D

func _ready():
	detector.body_entered.connect(_on_body_entered)
	
	if has_node("DoorPortal"):
		get_node("DoorPortal").queue_free()
		
	# 1. Create Door Frame
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.15, 0.1, 0.05)
	frame_mat.roughness = 0.9
	
	var left_pillar = MeshInstance3D.new()
	left_pillar.mesh = BoxMesh.new()
	left_pillar.mesh.size = Vector3(0.2, 2.8, 0.2)
	left_pillar.position = Vector3(-0.8, 1.4, 0)
	left_pillar.material_override = frame_mat
	add_child(left_pillar)
	
	var right_pillar = MeshInstance3D.new()
	right_pillar.mesh = BoxMesh.new()
	right_pillar.mesh.size = Vector3(0.2, 2.8, 0.2)
	right_pillar.position = Vector3(0.8, 1.4, 0)
	right_pillar.material_override = frame_mat
	add_child(right_pillar)
	
	var top_beam = MeshInstance3D.new()
	top_beam.mesh = BoxMesh.new()
	top_beam.mesh.size = Vector3(1.8, 0.2, 0.2)
	top_beam.position = Vector3(0, 2.9, 0)
	top_beam.material_override = frame_mat
	add_child(top_beam)
	
	# 1.5 Fill the 4.0 meter gap with walls so it connects to the maze realistically!
	var filler_mat = StandardMaterial3D.new()
	var wall_tex = load("res://wall_texture.png")
	if wall_tex:
		filler_mat.albedo_texture = wall_tex
		filler_mat.uv1_triplanar = false
	else:
		filler_mat.albedo_color = Color(0.08, 0.08, 0.12, 1)
		
	var left_wall_filler = MeshInstance3D.new()
	left_wall_filler.mesh = BoxMesh.new()
	left_wall_filler.mesh.size = Vector3(1.1, 3.0, 4.0) # Match CELL_SIZE depth
	left_wall_filler.position = Vector3(-1.45, 1.5, 0)
	left_wall_filler.material_override = filler_mat
	add_child(left_wall_filler)
	
	var right_wall_filler = MeshInstance3D.new()
	right_wall_filler.mesh = BoxMesh.new()
	right_wall_filler.mesh.size = Vector3(1.1, 3.0, 4.0) # Match CELL_SIZE depth
	right_wall_filler.position = Vector3(1.45, 1.5, 0)
	right_wall_filler.material_override = filler_mat
	add_child(right_wall_filler)
	
	# 2. Create the Door Panel (cracked open)
	var door_pivot = Node3D.new()
	door_pivot.position = Vector3(0.7, 1.4, 0)
	add_child(door_pivot)
	
	var door_panel = MeshInstance3D.new()
	door_panel.mesh = BoxMesh.new()
	door_panel.mesh.size = Vector3(1.4, 2.8, 0.1)
	door_panel.position = Vector3(-0.7, 0, 0)
	
	var door_mat = StandardMaterial3D.new()
	var d_tex = load("res://exit_door.png")
	if d_tex:
		door_mat.albedo_texture = d_tex
		door_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	else:
		door_mat.albedo_color = Color(0.25, 0.15, 0.08)
	door_mat.roughness = 0.8
	door_panel.material_override = door_mat
	door_pivot.add_child(door_panel)
	
	# Rotate door slightly open
	door_pivot.rotation.y = deg_to_rad(-60.0) 
	
	# 3. Add Blinding Escape Light
	var escape_light = SpotLight3D.new()
	escape_light.light_color = Color(0.8, 0.9, 1.0)
	escape_light.light_energy = 25.0
	escape_light.spot_range = 30.0
	escape_light.spot_angle = 70.0
	escape_light.position = Vector3(0, 1.5, -2.5)
	escape_light.rotation.y = deg_to_rad(180.0)
	escape_light.shadow_enabled = true
	add_child(escape_light)
	
	# 4. Add glowing void behind door
	var void_glow = MeshInstance3D.new()
	void_glow.mesh = BoxMesh.new()
	void_glow.mesh.size = Vector3(5.0, 4.0, 0.5)
	void_glow.position = Vector3(0, 1.5, -3.5)
	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 1.0, 1.0)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.8, 0.9, 1.0)
	glow_mat.emission_energy_multiplier = 4.0
	void_glow.material_override = glow_mat
	add_child(void_glow)

func _on_body_entered(body):
	if body.is_in_group("player"):
		var main = get_tree().current_scene
		if main and main.has_method("win_game"):
			main.win_game()
