extends Area3D

@export var consumable_type: int = 0 # 0 = Water, 1 = Booster

func _ready():
	body_entered.connect(_on_body_entered)
	var mesh_inst = $MeshInstance3D
	var mat = StandardMaterial3D.new()
	if consumable_type == 0:
		mat.albedo_color = Color(0.0, 0.5, 1.0) # Blue for water
	else:
		mat.albedo_color = Color(1.0, 0.0, 0.0) # Red for booster
	mesh_inst.material_override = mat

func _on_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("drink_consumable"):
			body.drink_consumable()
		queue_free()
