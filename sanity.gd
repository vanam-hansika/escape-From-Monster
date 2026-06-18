extends Node

@export var max_sanity: float = 100.0
@export var current_sanity: float = 100.0
@export var dark_decay_rate: float = 1.5
@export var light_decay_rate: float = 0.2
@export var monster_near_decay_rate: float = 12.0

@onready var player = get_parent()
var monster: CharacterBody3D = null

func _ready():
	call_deferred("find_monster")

func find_monster():
	var monsters = get_tree().get_nodes_in_group("monster")
	if monsters.size() > 0:
		monster = monsters[0]

func update_sanity(delta: float, is_dark: bool):
	var decay = 0.0
	
	if is_dark:
		decay += dark_decay_rate
	else:
		decay += light_decay_rate
		
	if not monster:
		find_monster()
		
	if monster:
		var dist = player.global_position.distance_to(monster.global_position)
		if dist < 15.0:
			# Decreases rapidly as monster gets closer
			var proximity_factor = (15.0 - dist) / 15.0
			decay += proximity_factor * monster_near_decay_rate
			
	current_sanity = max(current_sanity - decay * delta, 0.0)
	
	if current_sanity <= 0.0:
		var main = get_tree().current_scene
		if main and main.has_method("game_over_sanity"):
			main.game_over_sanity()
