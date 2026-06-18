extends SpotLight3D

@export var max_battery: float = 100.0
@export var current_battery: float = 100.0
@export var battery_drain_rate: float = 0.8
@export var flicker_threshold: float = 25.0

var is_on: bool = true
var default_energy: float = 1.0
var flicker_timer: float = 0.0

func _ready():
	light_energy = 20.0 # Extremely bright and clear
	spot_range = 100.0
	spot_angle = 50.0
	light_color = Color(1.0, 1.0, 0.98) # Pure, clear white with a tiny hint of warmth
	
	# Removed the complex textured projector so the light is perfectly clear and illuminates walls brightly!
	light_projector = null
	
	default_energy = light_energy
	visible = is_on

func toggle():
	if current_battery > 0.0:
		is_on = !is_on
		visible = is_on
	else:
		is_on = false
		visible = false

func _process(delta):
	# Battery drain removed as requested.
	pass
