extends Node3D
class_name Main

static var is_replaying: bool = false
static var selected_gender: String = "male"

@onready var ui = $UI
@onready var audio_manager = $AudioManager
@onready var player = $NavigationRegion3D/Player
@onready var monster = $NavigationRegion3D/Monster
@onready var exit_door = $NavigationRegion3D/ExitDoor
@onready var nav_region = $NavigationRegion3D

var game_ended = false
var game_started = false
var CELL_SIZE = 4.0

# 1 = Wall, 0 = Empty path, 2 = Safe Room (door faces -Z), 3 = Safe Room (door faces +Z)
var maze_grid = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,0,0,0,0,1,1,1,0,0],
	[1,0,1,1,1,0,1,0,0,0,0,0,1],
	[1,0,1,2,0,0,1,0,1,1,1,0,1],
	[1,0,1,1,1,1,1,0,1,3,1,0,1],
	[1,0,0,0,0,0,1,0,1,0,0,0,1],
	[1,0,1,1,1,0,1,0,1,1,1,0,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,1],
	[1,0,1,0,3,1,1,1,1,0,1,0,1],
	[1,0,1,0,0,0,0,0,0,0,1,0,1],
	[1,0,1,1,1,1,1,1,1,0,1,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1]
]

var safe_room_scene = preload("res://safe_room.tscn")

# Cinematic nodes
var cinematic_world: Node3D
var intro_camera: Camera3D
var character_sprite: Sprite3D
var monster_sprite: Sprite3D
var lightning_light: DirectionalLight3D
var lamp_light: SpotLight3D
var lightning_cooldown = 0.0
var fade_materials = []
var sign_mat: StandardMaterial3D
var window_material: StandardMaterial3D

func _ready():
	# 1. Generate Floor
	create_floor(Vector3(26.0, -0.1, 26.0), Vector3(52.0, 0.2, 52.0))
	
	# 1.5. Generate Ceiling (Blocks sky lighting completely for maximum horror and flashlight effect)
	create_ceiling(Vector3(26.0, 3.1, 26.0), Vector3(52.0, 0.2, 52.0))
	
	# 2. Generate Walls and Safe Rooms
	for r in range(maze_grid.size()):
		for c in range(maze_grid[r].size()):
			if maze_grid[r][c] == 1:
				var wall_pos = Vector3(c * CELL_SIZE + CELL_SIZE / 2.0, 1.5, r * CELL_SIZE + CELL_SIZE / 2.0)
				create_wall(wall_pos, Vector3(CELL_SIZE, 3.0, CELL_SIZE))
			elif maze_grid[r][c] == 2 or maze_grid[r][c] == 3:
				var safe_pos = Vector3(c * CELL_SIZE + CELL_SIZE / 2.0, 0.0, r * CELL_SIZE + CELL_SIZE / 2.0)
				var safe_inst = safe_room_scene.instantiate()
				safe_inst.position = safe_pos
				# Orient door: 2 faces +X (rotation y=90), 3 faces +Z (rotation y=0)
				if maze_grid[r][c] == 2:
					safe_inst.rotation.y = deg_to_rad(90)
				else:
					safe_inst.rotation.y = 0.0
				nav_region.add_child(safe_inst)
				
	# 3. Position Player, Monster, and Exit Door
	player.global_position = cell_to_world(Vector2i(1, 1), 0.2)
	monster.global_position = cell_to_world(Vector2i(11, 11), 0.2)
	
	# Move door to the outer boundary so it perfectly replaces the wall!
	exit_door.global_position = cell_to_world(Vector2i(12, 1), 0.0)
	exit_door.rotation.y = deg_to_rad(-90.0)
	
	# Setup configuration based on replay state
	if is_replaying:
		# Directly start gameplay mode
		game_started = true
		player.setup_gender(selected_gender)
		player.can_move = true
		player.flashlight.is_on = true
		player.flashlight.visible = true
		ui.get_node("HUD").visible = true
		
		# Bake Navigation Mesh and defer monster start
		setup_nav_mesh()
		call_deferred("bake_nav")
	else:
		# Setup Cinematic mode
		player.can_move = false
		player.flashlight.is_on = false
		player.flashlight.visible = false
		ui.get_node("HUD").visible = false
		
		# Stop monster movement/physics
		monster.set_physics_process(false)
		
		# Construct the outdoor cinematic world
		construct_cinematic_world()
		if intro_camera:
			intro_camera.current = true
		
		# Play ambient wind loop
		if audio_manager:
			audio_manager.play_cinematic_ambient()
			
		# Play wolf sound (Setup only, play it after selection)
		var wolf_player = AudioStreamPlayer.new()
		wolf_player.name = "WolfPlayer"
		var wolf_stream = load("res://wolf.wav")
		if not wolf_stream:
			wolf_stream = load("res://wolf.mp3")
		if wolf_stream:
			wolf_player.stream = wolf_stream
			wolf_player.volume_db = 0.0
			add_child(wolf_player)
			
		# Instantiate Character Selection Screen
		var char_select_scene = load("res://character_selection.tscn")
		var char_select_inst = char_select_scene.instantiate()
		char_select_inst.character_selected.connect(_on_character_selected)
		add_child(char_select_inst)
		
		# Defer navigation baking
		setup_nav_mesh()
		call_deferred("bake_nav_only")

func setup_nav_mesh():
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.8
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_region.navigation_mesh = nav_mesh

func bake_nav():
	print("LOG: Starting navigation mesh baking...")
	if not nav_region or not nav_region.navigation_mesh:
		return
	nav_region.bake_navigation_mesh(false)
	print("LOG: Navigation mesh baking completed successfully!")
	if monster:
		monster.set_physics_process(true)

func bake_nav_only():
	print("LOG: Baking navigation mesh in background...")
	if not nav_region or not nav_region.navigation_mesh:
		return
	nav_region.bake_navigation_mesh(false)
	# Do NOT start monster physics process here, as we are in cinematic mode!

func cell_to_world(cell: Vector2i, height_offset: float) -> Vector3:
	return Vector3(
		cell.x * CELL_SIZE + CELL_SIZE / 2.0,
		height_offset,
		cell.y * CELL_SIZE + CELL_SIZE / 2.0
	)

# ================= CINEMATIC WORLD CONSTRUCTION =================

func construct_cinematic_world():
	cinematic_world = Node3D.new()
	cinematic_world.name = "CinematicWorld"
	cinematic_world.position = Vector3(-60.0, 0.0, -60.0) # Far away from the main maze
	add_child(cinematic_world)
	
	# 1. Floor
	var floor_mesh_inst = MeshInstance3D.new()
	var floor_mesh = BoxMesh.new()
	floor_mesh.size = Vector3(30, 0.2, 30)
	floor_mesh_inst.mesh = floor_mesh
	
	var floor_material = StandardMaterial3D.new()
	# Match the dark, moody, wet ground in the laboratory image
	floor_material.albedo_color = Color(0.02, 0.02, 0.025) # Very dark grey/blue
	floor_material.roughness = 0.25 # Make it slightly shiny/wet looking
	floor_material.metallic = 0.4
	floor_mesh_inst.material_override = floor_material
	cinematic_world.add_child(floor_mesh_inst)
	
	# 2. Lab Exterior Facade Wall
	var wall_mesh_inst = MeshInstance3D.new()
	var wall_mesh = QuadMesh.new()
	wall_mesh.size = Vector2(12.0, 8.0) # Bigger so camera sees full image without cropping
	wall_mesh_inst.mesh = wall_mesh
	wall_mesh_inst.position = Vector3(0, 4.0, -8.0) # Higher Y so top isn't cut, further back
	
	# Initialize/clear materials list
	fade_materials.clear()
	
	var wall_material = StandardMaterial3D.new()
	var wall_tex = load_texture_safe("res://laboratory2.png")
	if not wall_tex:
		wall_tex = load_texture_safe("res://laboratory.jpeg")
		
	if wall_tex:
		wall_material.albedo_texture = wall_tex
		wall_material.uv1_scale = Vector3(1.0, 1.0, 1.0)
		wall_material.uv1_triplanar = false
		
		# UNSHADED = renders image exactly as-is, no white layer, no light interference
		wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wall_material.emission_enabled = false
		wall_material.specular = 0.0
		wall_material.roughness = 1.0
	else:
		wall_material.albedo_color = Color(0.2, 0.2, 0.2)
	
	wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wall_material.albedo_color.a = 0.0
	wall_mesh_inst.material_override = wall_material
	fade_materials.append(wall_material)
	cinematic_world.add_child(wall_mesh_inst)
	
	# 2a. Removed 3D facade elements (Pillars, Canopy, Door, Window) per user request to unblock the image
	
	# 5. Character Sprite (Initially hidden, revealed on selection)
	character_sprite = Sprite3D.new()
	character_sprite.position = Vector3(0.0, 1.1, -2.5)
	character_sprite.pixel_size = 0.0065
	character_sprite.billboard = 2 # Face camera Y
	character_sprite.visible = false
	cinematic_world.add_child(character_sprite)
	
	# 6. Monster Silhouette Sprite (Initially hidden, flashes during shock moment)
	monster_sprite = Sprite3D.new()
	monster_sprite.position = Vector3(0.0, 4.5, -5.6)
	monster_sprite.texture = load("res://custom_devil.png")
	monster_sprite.pixel_size = 0.002
	monster_sprite.modulate = Color(0, 0, 0, 1) # Pure black silhouette
	monster_sprite.visible = false
	cinematic_world.add_child(monster_sprite)
	
	# 7. Intro Camera
	intro_camera = Camera3D.new()
	intro_camera.fov = 60.0
	intro_camera.near = 0.05
	# Start high and far back so the full lab image fits on screen
	intro_camera.position = Vector3(0.0, 5.0, 8.0)
	intro_camera.rotation_degrees = Vector3(-15.0, 0.0, 0.0)
	cinematic_world.add_child(intro_camera)
	
	# 8. Lights
	var moonlight = DirectionalLight3D.new()
	moonlight.light_color = Color(0.25, 0.35, 0.55)
	moonlight.light_energy = 0.08
	moonlight.rotation_degrees = Vector3(-45, 45, 0)
	cinematic_world.add_child(moonlight)
	
	lamp_light = SpotLight3D.new()
	lamp_light.position = Vector3(0.0, 3.5, -4.5)
	lamp_light.rotation_degrees = Vector3(-70, 0, 0)
	lamp_light.light_color = Color(1.0, 0.85, 0.7)
	lamp_light.light_energy = 2.0
	lamp_light.spot_range = 10.0
	lamp_light.spot_angle = 60.0
	cinematic_world.add_child(lamp_light)
	
	lightning_light = DirectionalLight3D.new()
	lightning_light.light_color = Color(1.0, 1.0, 1.0)
	lightning_light.light_energy = 0.0
	lightning_light.visible = true
	cinematic_world.add_child(lightning_light)
	
	# 9. Spawning Forest Trees
	var tree_positions = []
	for x in range(3):
		for z in range(6):
			var z_pos = randf_range(-4.0, 3.0)
			var x_pos = randf_range(-10.0, 10.0)
			# Keep a wide path clear so trees don't cut off the edges of the laboratory image
			if abs(x_pos) < 5.0:
				if x_pos < 0: x_pos -= 5.0
				else: x_pos += 5.0
			tree_positions.append(Vector3(x_pos, 0.0, z_pos))
				
	for pos in tree_positions:
		create_tree(pos)

func create_tree(pos: Vector3):
	var tree_node = Node3D.new()
	tree_node.position = pos
	cinematic_world.add_child(tree_node)
	
	# Trunk
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = 2.2
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0.0, 1.1, 0.0)
	
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.18, 0.12, 0.08) # Brown
	trunk_mat.roughness = 0.95
	trunk.material_override = trunk_mat
	tree_node.add_child(trunk)
	
	# Foliage (Cones stacked using CylinderMesh with top_radius=0)
	for i in range(3):
		var foliage = MeshInstance3D.new()
		var foliage_mesh = CylinderMesh.new()
		foliage_mesh.top_radius = 0.0
		foliage_mesh.bottom_radius = 1.0 - i * 0.25
		foliage_mesh.height = 1.5 - i * 0.2
		foliage.mesh = foliage_mesh
		foliage.position = Vector3(0.0, 1.8 + i * 0.9, 0.0)
		
		var foliage_mat = StandardMaterial3D.new()
		foliage_mat.albedo_color = Color(0.04, 0.12, 0.06) # Dark pine green
		foliage_mat.roughness = 0.9
		foliage.material_override = foliage_mat
		tree_node.add_child(foliage)

# ================= CINEMATIC STATE MACHINE =================

func _on_character_selected(gender: String):
	selected_gender = gender
	
	# Start playing the wolf sound now!
	var wolf_player = get_node_or_null("WolfPlayer")
	if wolf_player and not wolf_player.playing:
		wolf_player.play()
	
	# Load correct model on player
	player.setup_gender(selected_gender)
	
	# Set and reveal character standing outside
	if gender == "female":
		character_sprite.texture = load_texture_safe("res://standing_female.png")
	else:
		character_sprite.texture = load_texture_safe("res://standing_male.png")
	character_sprite.visible = true
	
	# Make Intro Camera current
	intro_camera.current = true
	
	# Transition Camera from drone to close up shot
	var cam_tween = create_tween().set_parallel(true)
	cam_tween.tween_property(intro_camera, "position", Vector3(0.0, 2.0, 3.0), 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(intro_camera, "rotation_degrees", Vector3(-5.0, 0.0, 0.0), 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Fade in all laboratory facade materials as the camera moves past the first trees
	for mat in fade_materials:
		if mat:
			cam_tween.tween_property(mat, "albedo_color:a", 1.0, 4.0).set_delay(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
	# Fade in warning sign and window lights emission
	if sign_mat:
		cam_tween.tween_property(sign_mat, "emission_energy_multiplier", 0.5, 4.0).set_delay(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if window_material:
		cam_tween.tween_property(window_material, "emission_energy_multiplier", 0.2, 4.0).set_delay(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await cam_tween.finished
	
	# Load Dialogue System Overlay
	var dialogue_scene = load("res://dialogue_system.tscn")
	var dialogue_inst = dialogue_scene.instantiate()
	dialogue_inst.character_gender = selected_gender
	dialogue_inst.enter_laboratory_pressed.connect(_on_enter_laboratory_pressed)
	add_child(dialogue_inst)

func _process(delta):
	# Handle atmospheric effects (streetlamp flicker, random lightning)
	if cinematic_world and not game_started:
		# Streetlight flicker
		if lamp_light:
			if randf() < 0.07:
				lamp_light.light_energy = randf_range(0.2, 2.4)
			else:
				lamp_light.light_energy = lerp(lamp_light.light_energy, 2.0, delta * 12.0)
				
		# Lightning flash
		if lightning_light:
			if lightning_cooldown <= 0.0:
				if randf() < 0.005: # Flash trigger
					lightning_light.light_energy = randf_range(4.0, 6.0)
					lightning_cooldown = randf_range(2.5, 6.5)
			else:
				lightning_cooldown -= delta
				lightning_light.light_energy = lerp(lightning_light.light_energy, 0.0, delta * 8.0)

func _on_enter_laboratory_pressed():
	# Stop wolf sound if playing
	var wolf_player = get_node_or_null("WolfPlayer")
	if wolf_player:
		wolf_player.stop()
		wolf_player.queue_free()
		
	# Zoom camera to the entry door (which is higher up in the new image, around Y=3.2)
	var zoom_tween = create_tween().set_parallel(true)
	zoom_tween.tween_property(intro_camera, "position", Vector3(0.0, 3.2, -4.5), 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Halfway through the zoom, play horror sting
	await get_tree().create_timer(1.0).timeout
	
	# Play horror sting sound
	var sting_player = AudioStreamPlayer.new()
	add_child(sting_player)
	sting_player.stream = load("res://horror_sting.wav")
	sting_player.volume_db = 2.0
	sting_player.play()
		
	# Flicker effect overlay
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	var flicker_rect = ColorRect.new()
	flicker_rect.anchors_preset = Control.PRESET_FULL_RECT
	flicker_rect.color = Color(0.8, 0.0, 0.0, 0.4)
	canvas.add_child(flicker_rect)
	
	for i in range(12):
		flicker_rect.visible = !flicker_rect.visible
		if randf() < 0.5:
			flicker_rect.color = Color(0, 0, 0, 0.85)
		else:
			flicker_rect.color = Color(0.8, 0, 0, 0.4)
		await get_tree().create_timer(0.05).timeout
		

		
	flicker_rect.visible = true
	flicker_rect.color = Color(0, 0, 0, 1) # Hold black
	
	await zoom_tween.finished
	
	canvas.queue_free()
	sting_player.queue_free()
	
	# Transition to objectives display
	show_objectives()

func show_objectives():
	var canvas = CanvasLayer.new()
	canvas.layer = 101
	add_child(canvas)
	
	# Root control node to allow modulation/fading
	var root_control = Control.new()
	root_control.anchors_preset = Control.PRESET_FULL_RECT
	canvas.add_child(root_control)
	
	var bg = ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.02, 0.02, 0.03, 1.0)
	root_control.add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_control.add_child(vbox)
	
	var title = Label.new()
	title.text = "OBJECTIVES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1, 1.0))
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	var objectives = [
		"• Find the Exit",
		"• Avoid the Monster",
		"• Use Safe Rooms to Survive",
		"• Manage Your Stamina Carefully"
	]
	
	for obj in objectives:
		var lbl = Label.new()
		lbl.text = obj
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		vbox.add_child(lbl)
		
	# Recenter box size
	vbox.size = Vector2(500, 300)
	vbox.position = (get_viewport().get_visible_rect().size - vbox.size) / 2.0
	
	# Animate fade in, hold, fade out
	root_control.modulate.a = 0.0
	var fade_in = create_tween()
	fade_in.tween_property(root_control, "modulate:a", 1.0, 0.5)
	
	await get_tree().create_timer(3.0).timeout
	
	var fade_out = create_tween()
	fade_out.tween_property(root_control, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	
	canvas.queue_free()
	
	# Start gameplay
	start_gameplay()

func start_gameplay():
	game_started = true
	
	# Stop ambient wind sound
	if audio_manager:
		audio_manager.stop_cinematic_ambient()
		
	# Switch back to player first person camera
	player.camera.current = true
	
	# Enable player movement, turn on flashlight
	player.can_move = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	player.flashlight.is_on = true
	player.flashlight.visible = true
	
	# Show gameplay HUD
	ui.get_node("HUD").visible = true
	
	# Start monster physics and movement
	if monster:
		monster.set_physics_process(true)
		
	# Free cinematic nodes
	if cinematic_world:
		cinematic_world.queue_free()
		cinematic_world = null

# ================= GAMEPLAY SCENE PROCEDURAL WALLS =================

func create_floor(pos: Vector3, size: Vector3):
	var static_body = StaticBody3D.new()
	static_body.position = pos
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	var tex = load("res://floor_texture.png")
	if tex:
		material.albedo_texture = tex
		material.albedo_color = Color(0.8, 0.8, 0.8, 1)
		material.uv1_scale = Vector3(0.05, 0.05, 0.05)
		material.uv1_triplanar = true
	else:
		material.albedo_color = Color(0.12, 0.12, 0.12, 1)
	
	material.roughness = 0.95
	mesh_inst.material_override = material
	static_body.add_child(mesh_inst)
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	static_body.add_child(col_shape)
	nav_region.add_child(static_body)

func create_ceiling(pos: Vector3, size: Vector3):
	var static_body = StaticBody3D.new()
	static_body.position = pos
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	var tex = load("res://ceiling_texture.png")
	if tex:
		material.albedo_texture = tex
		material.albedo_color = Color(0.8, 0.8, 0.8, 1)
		material.uv1_scale = Vector3(0.05, 0.05, 0.05)
		material.uv1_triplanar = true
	else:
		material.albedo_color = Color(0.04, 0.04, 0.04, 1)
		
	material.roughness = 0.95
	mesh_inst.material_override = material
	static_body.add_child(mesh_inst)
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	static_body.add_child(col_shape)
	nav_region.add_child(static_body)

func create_wall(pos: Vector3, size: Vector3):
	var static_body = StaticBody3D.new()
	static_body.position = pos
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	var tex = load("res://wall_texture.png")
	if tex:
		material.albedo_texture = tex
		material.albedo_color = Color(0.8, 0.8, 0.8, 1)
		material.uv1_scale = Vector3(1.0, 1.0, 1.0)
		material.uv1_triplanar = false
	else:
		material.albedo_color = Color(0.08, 0.08, 0.12, 1)
	
	material.roughness = 0.85
	mesh_inst.material_override = material
	static_body.add_child(mesh_inst)
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	static_body.add_child(col_shape)
	nav_region.add_child(static_body)

# ================= WIN / GAME OVER CONDITIONS =================

func win_game():
	if game_ended: return
	game_ended = true
	player.disable_movement()
	if monster:
		monster.queue_free()
	if audio_manager and audio_manager.has_method("play_win"):
		audio_manager.play_win()
	ui.show_win()

func game_over_monster():
	if game_ended: return
	game_ended = true
	player.disable_movement()
	audio_manager.play_jumpscare()
	ui.show_lose(true)

func game_over_sanity():
	if game_ended: return
	game_ended = true
	player.disable_movement()
	ui.show_lose(false)

func load_texture_safe(path: String) -> Texture2D:
	var tex = load(path)
	if tex:
		return tex
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null
