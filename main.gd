extends Node3D

@onready var ui = $UI
@onready var audio_manager = $AudioManager
@onready var player = $NavigationRegion3D/Player
@onready var monster = $NavigationRegion3D/Monster
@onready var exit_door = $NavigationRegion3D/ExitDoor
@onready var nav_region = $NavigationRegion3D

var game_ended = false
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
	
	# 4. Bake Navigation Mesh
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.8
	nav_mesh.agent_max_slope = 45.0
	nav_region.navigation_mesh = nav_mesh
	
	# Call bake (needs to be deferred slightly to allow nodes to enter tree completely)
	call_deferred("bake_nav")

func bake_nav():
	nav_region.bake_navigation_mesh(false)
	# Force the monster to start moving immediately after baking is complete!
	if monster:
		monster.set_physics_process(true)

func _on_bake_finished():
	monster.set_physics_process(true)

func cell_to_world(cell: Vector2i, height_offset: float) -> Vector3:
	return Vector3(
		cell.x * CELL_SIZE + CELL_SIZE / 2.0,
		height_offset,
		cell.y * CELL_SIZE + CELL_SIZE / 2.0
	)

func create_floor(pos: Vector3, size: Vector3):
	var static_body = StaticBody3D.new()
	static_body.position = pos
	
	# Mesh
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	
	# Material
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
	material.roughness = 0.9
	mesh_inst.material_override = material
	
	static_body.add_child(mesh_inst)
	
	# Collision
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	
	static_body.add_child(col_shape)
	nav_region.add_child(static_body)

func create_ceiling(pos: Vector3, size: Vector3):
	var static_body = StaticBody3D.new()
	static_body.position = pos
	
	# Mesh
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	
	# Material
	var material = StandardMaterial3D.new()
	var tex = load("res://ceiling_texture.png")
	if tex:
		material.albedo_texture = tex
		material.albedo_color = Color(0.8, 0.8, 0.8, 1)
		material.uv1_scale = Vector3(0.05, 0.05, 0.05) # Massive scale so it repeats very rarely, avoiding tile-look
		material.uv1_triplanar = true # Re-enabled to fix UV washout
	else:
		material.albedo_color = Color(0.04, 0.04, 0.04, 1) # Dark gray ceiling
		
	material.roughness = 0.95
	mesh_inst.material_override = material
	
	static_body.add_child(mesh_inst)
	
	# Collision
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	
	static_body.add_child(col_shape)
	nav_region.add_child(static_body)

func create_wall(pos: Vector3, size: Vector3):
	var static_body = StaticBody3D.new()
	static_body.position = pos
	
	# Mesh
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	
	# Material
	var material = StandardMaterial3D.new()
	var tex = load("res://wall_texture.png")
	if tex:
		material.albedo_texture = tex
		material.albedo_color = Color(0.8, 0.8, 0.8, 1)
		material.uv1_scale = Vector3(1.0, 1.0, 1.0)
		material.uv1_triplanar = false # Disabled to prevent tile-like repeating
	else:
		material.albedo_color = Color(0.08, 0.08, 0.12, 1)
	
	material.roughness = 0.85
	mesh_inst.material_override = material
	
	static_body.add_child(mesh_inst)
	
	# Collision
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col_shape.shape = box_shape
	
	static_body.add_child(col_shape)
	nav_region.add_child(static_body)

func win_game():
	if game_ended: return
	game_ended = true
	player.disable_movement()
	if monster:
		monster.queue_free()
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
