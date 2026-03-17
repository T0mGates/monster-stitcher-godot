# Base class, extend to add new status effects
# Add to Enums.StatusID + make_status() in ActionResolver
class_name StatusEffect
extends Resource

# -1 = permanent
var turns_remaining	: int 			= 3
var owner_part		: BodyPartData 	= null

func _init(
	owner_part_param	: BodyPartData,
	turns_param			: int = 3,
) -> void:

	owner_part		= owner_part_param
	turns_remaining = turns_param

func get_id() -> Enums.StatusID:
	return Enums.StatusID.BLEED

func on_apply() -> void:
	pass

func on_turn_start() -> void:
	return

func on_remove() -> void:
	pass

func on_stack(new_effect: StatusEffect) -> void:
	turns_remaining = max(turns_remaining, new_effect.turns_remaining)

func tick() -> void:
	on_turn_start()
	if turns_remaining > 0:
		turns_remaining -= 1

func is_expired() -> bool:
	return turns_remaining == 0

class Dismembered extends StatusEffect:

	func get_id() -> Enums.StatusID:
		return Enums.StatusID.DISMEMBERED

	func on_stack(n: StatusEffect) -> void:
		turns_remaining = max(turns_remaining, n.turns_remaining)

	func on_turn_start() -> void:
		if owner_part == null:
			return

		var dmg: float = owner_part.max_hp / 5.0
		owner_part.take_damage(int(dmg))

class Bleed extends StatusEffect:

	func get_id() -> Enums.StatusID:
		return Enums.StatusID.BLEED

	func on_stack(n: StatusEffect) -> void:
		turns_remaining = turns_remaining + n.turns_remaining

	func on_turn_start() -> void:
		if owner_part == null:
			return

		owner_part.take_damage(turns_remaining)

class Poison extends StatusEffect:
	var damage_per_turn: int = 2
	func get_id() -> Enums.StatusID: return Enums.StatusID.POISON
	func on_stack(n: StatusEffect) -> void:
		damage_per_turn += 1
		turns_remaining = max(turns_remaining, n.turns_remaining)

	func on_turn_start() -> void:
		if owner_part == null:
			return

		owner_part.current_hp -= damage_per_turn
		damage_per_turn += 1

class Weak extends StatusEffect:
	var damage_multiplier: float = 0.5
	var _original_damage: int   = 0

	func get_id() -> Enums.StatusID:
		return Enums.StatusID.WEAK

	func on_apply() -> void:
		if owner_part and owner_part.move:
			_original_damage = owner_part.move.base_damage
			owner_part.move.base_damage = int(_original_damage * damage_multiplier)

	func on_remove() -> void:
		if owner_part and owner_part.move:
			owner_part.move.base_damage = _original_damage

class Stunned extends StatusEffect:
	func get_id() -> Enums.StatusID:
		return Enums.StatusID.STUNNED

	func on_turn_start() -> void:
		return

class Regenerating extends StatusEffect:
	var heal_per_turn: int = 3

	func get_id() -> Enums.StatusID:
		return Enums.StatusID.REGENERATING

	func on_turn_start() -> void:
		if owner_part == null:
			return

		var healed = mini(heal_per_turn, owner_part.max_hp - owner_part.current_hp)
		owner_part.current_hp += healed