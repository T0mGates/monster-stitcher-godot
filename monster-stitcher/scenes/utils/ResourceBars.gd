extends Node2D

var speed_bar	: ProgressBar
var energy_bar	: ProgressBar
var energy_label: RichTextLabel

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	speed_bar 		= get_node_or_null("SpeedBar/ProgressBar") as ProgressBar
	energy_bar 		= get_node_or_null("EnergyBar/ProgressBar") as ProgressBar
	energy_label	= get_node_or_null("EnergyBar/Label") as RichTextLabel

func update_resources(monster: MonsterBody):
	speed_bar.value 		= monster.speed_bar

	energy_bar.max_value 	= monster.max_energy
	energy_bar.value		= monster.current_energy

	energy_label.text		= "Energy: %d / %d" % [monster.current_energy, monster.max_energy]
