extends Node

@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0
@export var drain_rate: float = 20.0
@export var recover_rate: float = 10.0

func consume_stamina(delta: float):
	current_stamina = max(current_stamina - drain_rate * delta, 0.0)

func recover_stamina(delta: float):
	current_stamina = min(current_stamina + recover_rate * delta, max_stamina)
