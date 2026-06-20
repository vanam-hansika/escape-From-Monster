extends Area3D

var consumed = false
@onready var audio_manager = get_tree().current_scene.get_node_or_null("AudioManager")

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if consumed: return
	if body.is_in_group("player"):
		consumed = true
		
		# Restore sanity and stamina
		if body.has_node("Sanity"):
			body.get_node("Sanity").current_sanity = 100.0
		if body.has_node("Stamina"):
			body.get_node("Stamina").current_stamina = 100.0
			
		# Play drink sound
		if audio_manager and audio_manager.has_method("play_drink"):
			audio_manager.play_drink()
			
		queue_free()
