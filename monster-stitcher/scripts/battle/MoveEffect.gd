# Base class for all move effects. Extend to add new ones.
# ActionResolver calls effect.apply(ctx) for each effect on each target part.

class_name MoveEffect
extends Resource

class EffectContext:
	var user_part		: BodyPartData
	var target_monster	: MonsterBody
	var target_part		: BodyPartData

	func _init(
		user_part_param			: BodyPartData,
		target_monster_param	: MonsterBody,
		target_part_param		: BodyPartData
	) -> void:

		user_part 		= user_part_param
		target_monster 	= target_monster_param
		target_part 	= target_part_param

func apply(_ctx: EffectContext) -> void:
	pass

func describe() -> String:
	return ""

func get_affected_parts(ctx: EffectContext) -> Array[BodyPartData]:
	if not ctx.target_monster:
		return [ctx.target_part]

	var parts: Array[BodyPartData] = []
	for part in ctx.target_monster.parts:
		parts.append(part)

	return parts

# ── Damage ────────────────────────────────────────────────────────────────────
class Damage extends MoveEffect:
	var base_damage		: int              = 10
	var damage_type		: Enums.DamageType = Enums.DamageType.PHYSICAL
	var use_part_type	: bool             = true
	var crit_chance		: float            = 0.05
	var crit_multiplier	: float            = 1.75

	func _init(
		damage_param			: int,
		damage_type_param		: Enums.DamageType,
		use_part_type_param		: bool 				= true,
		crit_chance_param		: float 			= 0.05,
		crit_multiplier_param	: float				= 1.75
	) -> void:

		base_damage 	= damage_param
		damage_type 	= damage_type_param
		use_part_type 	= use_part_type_param
		crit_chance		= crit_chance_param
		crit_multiplier = crit_multiplier_param

	func apply(ctx: EffectContext) -> void:
		var raw: float 					= base_damage

		var atk_stat_to_use: int		= 0
		if Enums.DamageType.PHYSICAL == damage_type:
			atk_stat_to_use = ctx.user_part.parent_monster.aggregate(Enums.Stat.ATTACK)
		elif Enums.DamageType.MAGICAL == damage_type:
			atk_stat_to_use = ctx.user_part.parent_monster.aggregate(Enums.Stat.MAGIC_ATTACK)

		raw += atk_stat_to_use

		var crit := false

		if randf() <= ctx.user_part.parent_monster.crit_rate + crit_chance:
			raw = int(raw * crit_multiplier)
			crit = true

		print("pre-defense damage calculated as: %d" % [raw])

		# Apply defense before passing to damage_part (damage_part handles passives)
		var pre_passive = _apply_defense(int(raw), int(atk_stat_to_use), damage_type, ctx.target_monster if ctx.target_monster else ctx.target_part.parent_monster)

		# Now get all the parts that we will actually affect
		for part in get_affected_parts(ctx):

			var real_damage = pre_passive * randf_range(0.9, 1.1)

			# damage_part fires Thorns / DamageReduction passive internally
			real_damage 	= part.parent_monster.damage_part(
				part, real_damage, ctx.user_part
			)

			var mult = part.get_type_multiplier(ctx.user_part.type)
			BattleManager.log("%s [%s]%s → %s.%s  %d dmg%s" % [
				ctx.user_part.parent_monster.monster_name, ctx.user_part.move.move_name,
				" 💥CRIT!" if crit else "",
				part.parent_monster.monster_name, part.part_name, real_damage,
				" (x%.1f)" % mult if mult != 1.0 else ""]
			)

	static func _apply_defense(raw: int, attacker_atk: int, dtype: Enums.DamageType, tm: MonsterBody) -> int:
		var val: float = raw + attacker_atk

		match dtype:
			Enums.DamageType.TRUE:
				return raw

			Enums.DamageType.MAGICAL:
				print("val: %d, def: %d" % [val, tm.aggregate(Enums.Stat.MAGIC_DEFENSE)])
				return max(1, val * (val / (val + tm.aggregate(Enums.Stat.MAGIC_DEFENSE))))

			Enums.DamageType.PHYSICAL:
				print("val: %d, def: %d" % [val, tm.aggregate(Enums.Stat.DEFENSE)])
				return max(1, val * (val / (val + tm.aggregate(Enums.Stat.DEFENSE))))

			_:
				return raw

	func describe() -> String:
		return "%d %s dmg (crit %.0f%%)" % [
			base_damage, Enums.get_damage_type_label(damage_type), crit_chance * 100.0]


# ── HealPart ──────────────────────────────────────────────────────────────────
class HealPart extends MoveEffect:
	var amount: int = 10

	func _init(
		amount_param: int
	) -> void:
		amount = amount_param

	func apply(ctx: EffectContext) -> void:
		var hp_healed = ctx.target_part.heal(amount)
		BattleManager.log("💚 %s [%s] → %s.%s  +%d HP" % [
			ctx.user_part.parent_monster.monster_name, ctx.user_part.move.move_name,
			ctx.target_part.parent_monster.monster_name, ctx.target_part.part_name, hp_healed]
		)

	func describe() -> String: return "Heals target part for %d HP" % amount


# ── InflictStatus ─────────────────────────────────────────────────────────────
class InflictStatus extends MoveEffect:
	var status_id	: Enums.StatusID = Enums.StatusID.BLEED
	var chance		: float          = 0.25
	var turns		: int            = 3

	func _init(
		status_id_param	: Enums.StatusID,
		chance_param	: float,
		turns_param		: int
	) -> void:

		status_id 	= status_id_param
		chance 		= chance_param
		turns 		= turns_param

	func apply(ctx: EffectContext) -> void:
		if randf() >= chance + ctx.user_part.parent_monster.aggregate(Enums.Stat.LUCK) * 0.005:
			return

		var effect = ActionResolver.make_status(status_id, ctx.target_part, turns)

		if effect:
			ctx.target_part.apply_status(effect)
			BattleManager.log("🔴 %s.%s inflicted [%s]!" % [
				ctx.target_part.parent_monster.monster_name, ctx.target_part.part_name,
				Enums.get_status_label(status_id)]
			)

	func describe() -> String:
		return "%.0f%% → %s (%d turns)" % [
			chance * 100.0, Enums.get_status_label(status_id), turns
		]


# ── InflictStatusOnCrit ───────────────────────────────────────────────────────
class InflictStatusOnCrit extends MoveEffect:
	var status_id	: Enums.StatusID 	= Enums.StatusID.STUNNED
	var turns		: int     			= 1

	func _init(
		status_id_param	: Enums.StatusID,
		turns_param		: int
	) -> void:

		status_id 	= status_id_param
		turns 		= turns_param

	func apply(ctx: EffectContext) -> void:
		if not ctx.was_crit:
			return

		var effect = ActionResolver.make_status(status_id, ctx.target_part, turns)

		if effect:
			ctx.target_part.apply_status(effect)
			BattleManager.log("💥 Crit → [%s] on %s.%s!" % [
				Enums.get_status_label(status_id),
				ctx.target_monster.monster_name, ctx.target_part.part_name]
			)

	func describe() -> String:
		return "On crit: %s (%d turn(s))" % [Enums.get_status_label(status_id), turns]

# ── ModifyTargetStat ──────────────────────────────────────────────────────────
class ModifyTargetStat extends MoveEffect:
	var stat	: Enums.Stat = Enums.Stat.DEFENSE
	var delta	: int        = -2

	func _init(
		stat_param	: Enums.Stat,
		delta_param	: int
	) -> void:

		stat 	= stat_param
		delta 	= delta_param

	func apply(ctx: EffectContext) -> void:
		ctx.target_monster.body.base_stats[stat] = ctx.target_monster.body.base_stats.get(stat, 0) + delta

		BattleManager.log("📉 %s %s%d %s" % [ctx.target_monster.monster_name,
			"+" if delta > 0 else "", delta, Enums.get_stat_label(stat)])

	func describe() -> String:
		return "%s%d %s on target" % ["+" if delta > 0 else "", delta, Enums.get_stat_label(stat)]


# ── FillSpeedBar ──────────────────────────────────────────────────────────
class FillSpeedBar extends MoveEffect:
	var amount:     float = 30.0

	func _init(
		amount_param: float
	) -> void:
		amount = amount_param

	func apply(ctx: EffectContext) -> void:
		if ctx.target_monster and ctx.target_monster.is_alive():
			ctx.target_monster.speed_bar = minf(ctx.target_monster.speed_bar + amount, MonsterBody.SPEED_BAR_MAX)
			BattleManager.log("⚡ %s speed bar +%.0f" % [ctx.target_monster.monster_name, amount])

	func describe() -> String:
		var who = "target ally"

		if amount >= MonsterBody.SPEED_BAR_MAX:
			return "Grants %s an immediate turn" % who

		return "Fills %s speed bar by %.0f" % [who, amount]


# ── DrainEnergy ───────────────────────────────────────────────────────────────
class DrainEnergy extends MoveEffect:
	var drain_amount	: int  = 3
	var transfer		: bool = true

	func _init(
		drain_amount_param	: int,
		transfer_param		: bool
	) -> void:

		drain_amount 	= drain_amount_param
		transfer 		= transfer_param

	func apply(ctx: EffectContext) -> void:
		var actual = mini(drain_amount, ctx.target_monster.current_energy)
		ctx.target_monster.spend_energy(actual)

		if transfer:
			ctx.actor.spend_energy(-actual)

		BattleManager.log("🔋 %s drains %d energy from %s" % [
			ctx.actor.monster_name, actual, ctx.target_monster.monster_name]
		)

	func describe() -> String:
		return "Drains %d energy%s" % [drain_amount, ", transfers to self" if transfer else ""]


# ── HealActorOnHit ────────────────────────────────────────────────────────────
class HealActorOnHit extends MoveEffect:
	var ratio: float = 0.3

	func _init(
		ratio_param: float
	) -> void:

		ratio = ratio_param

	func apply(ctx: EffectContext) -> void:
		if ctx.damage_dealt <= 0: return
		var healed = int(ctx.damage_dealt * ratio)
		ctx.actor.current_hp = clampi(ctx.actor.current_hp + healed, 0, ctx.actor.max_hp)
		BattleManager.log("🩹 %s leeches %d HP" % [ctx.actor.monster_name, healed])

	func describe() -> String:
		return "Leeches %.0f%% of damage as HP" % [ratio * 100.0]


# ── ConditionalEffect ─────────────────────────────────────────────────────────
class ConditionalEffect extends MoveEffect:
	var inner_effect	: MoveEffect 		= null
	var condition		: Enums.Conditional = Enums.Conditional.TARGET_HAS_BLEED

	func _init(
		inner_effect_param	: MoveEffect,
		condition_param		: Enums.Conditional
	) -> void:

		inner_effect 	= inner_effect_param
		condition 		= condition_param

	func apply(ctx: EffectContext) -> void:
		if inner_effect == null:
			return

		var pass_cond = false

		match condition:
			Enums.Conditional.TARGET_HAS_BLEED:
				pass_cond = ctx.target_part.has_status(Enums.StatusID.BLEED)

			Enums.Conditional.TARGET_HP_BELOW_HALF:
				pass_cond = ctx.target_part.current_hp < ctx.target_part.max_hp / 2.0

			Enums.Conditional.ACTOR_HP_BELOW_HALF:
				pass_cond = ctx.actor.current_hp < ctx.actor.max_hp / 2.0

		if pass_cond:
			inner_effect.apply(ctx)

	func describe() -> String:
		return "If [%s]: %s" % [Enums.get_conditional_description(condition), inner_effect.describe() if inner_effect else "nothing"]
