extends Node
class_name ActionResolver

enum ResolutionType { ACTION, REST }

class ResolutionResult:
	extends RefCounted

	var type			: ResolutionType
	var user_part		: BodyPartData
	var target_monsters	: Array[MonsterBody]
	var target_parts	: Array[BodyPartData]
	var energy_gained	: int

	func _init(type_param: ResolutionType, user_part_param: BodyPartData, target_monsters_param: Array[MonsterBody], target_parts_param: Array[BodyPartData], energy_gained_param: int):
		type 			= type_param
		user_part 		= user_part_param
		target_monsters = target_monsters_param
		target_parts 	= target_parts_param
		energy_gained	= energy_gained_param

# ══════════════════════════════════════════════════════════════════════════════
# Main entry point
# ══════════════════════════════════════════════════════════════════════════════
static func resolve(
	user_part			: BodyPartData,
	target_monsters		: Array[MonsterBody],
	target_parts		: Array[BodyPartData]
) -> void:
	var result: ResolutionResult = ResolutionResult.new(
		ResolutionType.ACTION,
		user_part,
		target_monsters,
		target_parts,
		0
	)

	if not user_part.parent_monster.spend_energy(user_part.move.energy_cost):
		BattleManager.log("⚡ %s can't afford %s!" % [user_part.parent_monster.monster_name, user_part.move.move_name])
		BattleManager.emit_signal("action_resolved", result)
		return

	# Make sure to separate MONSTER targetting vs PART targetting

	for monster in target_monsters:

		var ctx = MoveEffect.EffectContext.new(
			user_part,
			monster,
			null
		)

		for effect in user_part.move.effects:
			effect.apply(ctx)

	for target_part in target_parts:
		if null == target_part:
			continue

		var ctx = MoveEffect.EffectContext.new(
			user_part,
			null,
			target_part
		)

		for effect in user_part.move.effects:
			effect.apply(ctx)

	BattleManager.emit_signal("action_resolved", result)


# ══════════════════════════════════════════════════════════════════════════════
# Target expansion
# ══════════════════════════════════════════════════════════════════════════════
static func expand_targets(
	user_part	: BodyPartData,
	target_part	: BodyPartData
) -> Array:
	# Returns a 2-tuple, [0] = targeted bodyparts, [1] = targeted monsters

	var ret_parts	: Array[BodyPartData] 	= []
	var ret_monsters: Array[MonsterBody] 	= []

	if target_part == null:
		return [ret_parts, ret_monsters]

	if not InputValidator.is_valid_click_target(user_part, target_part):
		return [ret_parts, ret_monsters]

	match user_part.move.target_mode:
		Enums.TargetMode.ENEMY_SINGLE_PART:
			if user_part.parent_monster.is_player_monster != target_part.parent_monster.is_player_monster:
				if target_part:
					ret_parts.append(target_part)

		Enums.TargetMode.ALLY_SINGLE_PART:
			if user_part.parent_monster.is_player_monster == target_part.parent_monster.is_player_monster:
				if target_part:
					ret_parts.append(target_part)

		Enums.TargetMode.ANY_SINGLE_PART:
			if target_part:
				ret_parts.append(target_part)

		Enums.TargetMode.ENEMY_WHOLE_MONSTER:
			if user_part.parent_monster.is_player_monster != target_part.parent_monster.is_player_monster:
				ret_monsters 	= [target_part.parent_monster]

		Enums.TargetMode.ALLY_WHOLE_MONSTER:
			if user_part.parent_monster.is_player_monster == target_part.parent_monster.is_player_monster:
				ret_monsters 	= [target_part.parent_monster]

		Enums.TargetMode.SELF_MONSTER:
			if user_part.parent_monster.monster_id == target_part.parent_monster.monster_id:
				ret_monsters 	= [target_part.parent_monster]

		Enums.TargetMode.ANY_SINGLE_MONSTER:
			ret_monsters 	= [target_part.parent_monster]

		Enums.TargetMode.ALLY_ALL:
			if user_part.parent_monster.is_player_monster == target_part.parent_monster.is_player_monster:

				var monsters = BattleManager.player_monsters if user_part.parent_monster.is_player_monster else BattleManager.enemy_monsters

				for monster in monsters:
					if monster.is_alive():
						ret_monsters.append(monster)

		Enums.TargetMode.ENEMY_ALL:
			if user_part.parent_monster.is_player_monster != target_part.parent_monster.is_player_monster:

				var monsters = BattleManager.enemy_monsters if user_part.parent_monster.is_player_monster else BattleManager.player_monsters

				for monster in monsters:
					if monster.is_alive():
						ret_monsters.append(monster)

	return [ret_parts, ret_monsters]


# ══════════════════════════════════════════════════════════════════════════════
# Status factory
# ══════════════════════════════════════════════════════════════════════════════
static func make_status(id: Enums.StatusID, owner_part: BodyPartData, turns: int) -> StatusEffect:
	var effect: StatusEffect

	match id:
		Enums.StatusID.BLEED:
			effect = StatusEffect.Bleed.new(owner_part, turns)

		Enums.StatusID.POISON:
			effect = StatusEffect.Poison.new(owner_part, turns)

		Enums.StatusID.WEAK:
			effect = StatusEffect.Weak.new(owner_part, turns)

		Enums.StatusID.STUNNED:
			effect = StatusEffect.Stunned.new(owner_part, turns)

		Enums.StatusID.REGENERATING:
			effect = StatusEffect.Regenerating.new(owner_part, turns)

		_:
			push_warning("make_status: unhandled StatusID %d" % id);
			return null

	effect.turns_remaining = turns
	return effect
