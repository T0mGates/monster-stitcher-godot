# Base class for all heart passive abilities.

# Trigger hooks (override whichever you need):
#   on_damage_received(ctx)   → called after damage is calculated, before it's applied
#   on_damage_dealt(ctx)      → called after this monster deals damage to any target
#   on_turn_start(ctx)        → called at the start of this monster's turn
#   on_part_destroyed(ctx)    → called when any of this monster's parts is destroyed

## To add a new passive:
##   1. Add its ID to Enums.HeartPassiveID (+ label/description there).
##   2. Create a subclass here (inner class) or in its own file.
##   3. Add a case to HeartPassive.make() factory at the bottom.
##   4. Done — MonsterBody calls the hooks automatically.

class_name HeartPassive
extends Resource


# ─── Trigger context ──────────────────────────────────────────────────────────
## Passed to every hook. Only the fields relevant to each trigger are filled.
class PassiveContext:
	# Damage hooks

	# Damage before this passive modifies it
	var raw_damage		: int  			= 0

	var user_monster	: MonsterBody	= null
	var user_part		: BodyPartData 	= null
	var target_part		: BodyPartData 	= null

	func _init(
		raw_damage_param		: int 			= 0,
		user_monster_param		: MonsterBody	= null,
		user_part_param			: BodyPartData 	= null,
		target_part_param		: BodyPartData 	= null
	) -> void:

		raw_damage 		= raw_damage_param
		user_monster	= user_monster_param
		user_part 		= user_part_param
		target_part 	= target_part_param


# ─── Passive identity ─────────────────────────────────────────────────────────
func get_id() -> Enums.HeartPassiveID:
	return Enums.HeartPassiveID.NONE

func describe() -> String:
	return Enums.get_passive_description(get_id())


# ─── Hooks — override in subclasses ──────────────────────────────────────────

# Called after damage is calculated but before it is applied
# Returns ACTUAL final damage
func on_damage_received(ctx: PassiveContext) -> int:
	return ctx.raw_damage

# Called after this monster successfully deals damage to a target
func on_damage_dealt(ctx: PassiveContext) -> void:
	pass

# Called at the start of this monster's turn (after status ticks)
func on_turn_start(ctx: PassiveContext) -> void:
	pass

# Called when any part on this monster is destroyed
func on_part_destroyed(ctx: PassiveContext) -> void:
	pass


# ══════════════════════════════════════════════════════════════════════════════
# PASSIVES
# ══════════════════════════════════════════════════════════════════════════════

# ── DamageReduction ──────────────────────────────────────────────────────────
# Flat reduction applied to every incoming hit, regardless of source.
class DamageReduction extends HeartPassive:
	@export var reduction: int = 3

	func get_id() -> Enums.HeartPassiveID:
		return Enums.HeartPassiveID.DAMAGE_REDUCTION

	func on_damage_received(ctx: PassiveContext) -> int:
		var reduced = max(0, ctx.raw_damage - reduction)
		if reduced < ctx.raw_damage:
			BattleManager.log("🛡 %s's heart absorbs %d damage (%d → %d)" % [
				ctx.user_part.parent_monster.monster_name, reduction, ctx.raw_damage, reduced]
			)

		return reduced

	func describe() -> String:
		return "Reduces all incoming damage by %d." % reduction


# ── Thorns ───────────────────────────────────────────────────────────────────
# Deals flat damage back to any attacker whenever this monster is hit by a physical attack
class Thorns extends HeartPassive:
	@export var reflect_damage: int = 3

	func get_id() -> Enums.HeartPassiveID:
		return Enums.HeartPassiveID.THORNS

	func on_damage_received(ctx: PassiveContext) -> int:
		if ctx.attacker == null or not ctx.attacker.is_alive() or not ctx.attacker_part.move.damage_type == Enums.DamageType.PHYSICAL:
			return ctx.raw_damage

		# Deal true damage directly to the attacker's bodypart they hit with
		ctx.attacked_part.take_damage(reflect_damage)
		BattleManager.log("🌵 Thorns! %s takes %d reflected damage." % [
			ctx.attacker.monster_name, reflect_damage]
		)

		return ctx.raw_damage

	func describe() -> String:
		return "Reflects %d damage to any attacker." % reflect_damage


# ── Vampiric ─────────────────────────────────────────────────────────────────
# Heals this monster's body HP for a portion of damage it deals to enemies.
class Vampiric extends HeartPassive:
	@export var leech_ratio: float = 0.25   # fraction of damage dealt

	func get_id() -> Enums.HeartPassiveID:
		return Enums.HeartPassiveID.VAMPIRIC

	func on_damage_dealt(ctx: PassiveContext) -> void:
		var healed = int(ctx.damage_dealt * leech_ratio)

		if healed <= 0:
			return

		ctx.user_monster.current_hp = clampi(
			ctx.user_monster.current_hp + healed, 0, ctx.user_monster.max_hp)
		BattleManager.log("🩸 %s leeches %d HP." % [ctx.user_monster.monster_name, healed]
		)

	func describe() -> String:
		return "Heals for %.0f%% of all damage dealt." % [leech_ratio * 100.0]


# ── Energised ─────────────────────────────────────────────────────────────────
# Grants bonus energy at the start of each turn, on top of normal regen.
class Energised extends HeartPassive:
	@export var bonus_energy: int = 2

	func get_id() -> Enums.HeartPassiveID:
		return Enums.HeartPassiveID.ENERGISED

	func on_turn_start(ctx: PassiveContext) -> void:
		ctx.user_monster.spend_energy(-bonus_energy)
		BattleManager.log("⚡ %s's heart sparks — +%d energy." % [
			ctx.user_monster.monster_name, bonus_energy]
		)

	func describe() -> String:
		return "Gains +%d energy at the start of each turn." % bonus_energy


# ── Resilient ─────────────────────────────────────────────────────────────────
# Once per battle, a hit that would reduce body HP to 0 leaves it at 1 instead.
class Resilient extends HeartPassive:
	var _used: bool = false

	func get_id() -> Enums.HeartPassiveID:
		return Enums.HeartPassiveID.RESILIENT

	func on_damage_received(ctx: PassiveContext) -> int:
		if _used:
			return ctx.raw_damage

		# Would this hit be lethal?
		if ctx.user_monster.current_hp - ctx.final_damage <= 0:
			_used = true
			BattleManager.log("💀 %s clings to life! (Resilient — used)" % ctx.user_monster.monster_name)
			return ctx.target_part.parent_monster.current_hp - 1

		return ctx.raw_damage

	func describe() -> String:
		var status := " [USED]" if _used else ""
		return "Once per battle: survive a lethal hit with 1 HP.%s" % status


# ── Swift ─────────────────────────────────────────────────────────────────────
# Adds a flat bonus to speed bar each tick, making this monster act more often.
# Applied in MonsterBody.aggregate() via a virtual stat contribution.
# We implement it as on_turn_start to top-up the bar instead.
class Swift extends HeartPassive:
	@export var speed_bonus: float = 15.0   # extra speed bar per tick

	func get_id() -> Enums.HeartPassiveID:
		return Enums.HeartPassiveID.SWIFT

	func on_turn_start(ctx: PassiveContext) -> void:
		# Top up the speed bar — effectively grants a head-start on the next turn
		ctx.user_monster.speed_bar = minf(
			ctx.user_monster.speed_bar + speed_bonus, MonsterBody.SPEED_BAR_MAX
		)

	func describe() -> String:
		return "Speed bar fills %.0f%% faster each turn." % speed_bonus


# ══════════════════════════════════════════════════════════════════════════════
# FACTORY
# MonsterBody calls this when loading heart data to instantiate the right class.
# ══════════════════════════════════════════════════════════════════════════════
static func make(id: Enums.HeartPassiveID) -> HeartPassive:
	match id:
		Enums.HeartPassiveID.DAMAGE_REDUCTION: return DamageReduction.new()
		Enums.HeartPassiveID.THORNS:           return Thorns.new()
		Enums.HeartPassiveID.VAMPIRIC:         return Vampiric.new()
		Enums.HeartPassiveID.ENERGISED:        return Energised.new()
		Enums.HeartPassiveID.RESILIENT:        return Resilient.new()
		Enums.HeartPassiveID.SWIFT:            return Swift.new()
		_:                                     return HeartPassive.new()   # NONE
