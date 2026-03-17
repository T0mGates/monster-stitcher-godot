# What a move does is entirely defined by its effects array
# See MoveEffect.gd for all available effects and how to add new ones
class_name MoveData
extends Resource

var move_name			: String 						= "Strike"
var description			: String 						= ""
var energy_cost			: int   						= 2

var move_type			: Enums.MoveType				= Enums.MoveType.MELEE

var target_mode			: Enums.TargetMode 				= Enums.TargetMode.ENEMY_SINGLE_PART
var target_row_pos_req	: Array[Enums.RowPosition] 		= [Enums.RowPosition.BACK, Enums.RowPosition.MID, Enums.RowPosition.FRONT]
var user_row_pos_req	: Array[Enums.RowPosition]		= [Enums.RowPosition.BACK, Enums.RowPosition.MID, Enums.RowPosition.FRONT]

## Applied in order per target part
## ctx.damage_dealt / ctx.was_crit carry forward between effects
var effects				: Array[MoveEffect] 			= []

var user_animation		: Enums.ClipRole
var target_animation	: Enums.ClipRole

func _init(
	name_param					: String,
	description_param			: String,
	energy_cost_param			: int,
	move_type_param				: Enums.MoveType,
	target_mode_param			: Enums.TargetMode,
	effects_param				: Array[MoveEffect],
	target_row_pos_req_param	: Array[Enums.RowPosition],
	user_row_pos_req_param		: Array[Enums.RowPosition],
	user_animation_param		: Enums.ClipRole,
	target_animation_param		: Enums.ClipRole
) -> void:

	move_name 			= name_param
	description 		= description_param
	energy_cost 		= energy_cost_param
	move_type 			= move_type_param
	target_mode 		= target_mode_param
	effects 			= effects_param
	target_row_pos_req 	= target_row_pos_req_param
	user_row_pos_req 	= user_row_pos_req_param
	user_animation		= user_animation_param
	target_animation	= target_animation_param

func is_heal_move() -> bool:
	for e in effects:
		if e is MoveEffect.HealPart:
			return true
	return false

func targets_allies() -> bool:
	return Enums.targets_allies(target_mode)

func has_damage() -> bool:
	for e in effects:
		if e is MoveEffect.Damage:
			return true
	return false

func get_effect_descriptions() -> Array[String]:
	var r: Array[String] = []
	for e in effects:
		var d = e.describe()
		if d != "": r.append(d)
	return r

func to_debug_string() -> String:
	return "[Move:%s|Cost:%d|Target:%s|Effects:%d]" % [
		move_name, energy_cost, Enums.get_target_label(target_mode), effects.size()
	]
