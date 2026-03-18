## Enums.gd
## NOT an autoload — plain class_name script.
## Enums defined here are visible project-wide and work in the Inspector dropdown.
## Remove "Enums" from your AutoLoad list.
class_name Enums
extends RefCounted

# ══════════════════════════════════════════════════════════════════════════════
# BODY PART SLOTS
# ══════════════════════════════════════════════════════════════════════════════
enum Slot { HEAD, ARM, LEG, TORSO, TAIL }

static func get_slot_label(s: Slot) -> String:
	return ["Head", "Arm", "Leg", "Torso", "Tail", "Heart"][s]


# ══════════════════════════════════════════════════════════════════════════════
# PART / MOVE TYPES
# ══════════════════════════════════════════════════════════════════════════════
enum PartType { DEMON, HOLY, BUG, SHARP, FLESH, ARCANE }

static func get_type_label(t: PartType) -> String:
	return ["Demon", "Holy", "Bug", "Sharp", "Flesh", "Arcane"][t]

static func get_type_matchup_hint(t: PartType) -> String:
	match t:
		PartType.SHARP:  return "Strong vs Bug · Weak vs Demon"
		PartType.BUG:    return "Strong vs Demon · Weak vs Holy"
		PartType.DEMON:  return "Strong vs Holy · Weak vs Sharp"
		PartType.HOLY:   return "Strong vs Sharp · Weak vs Bug"
	return "Neutral — no strengths or weaknesses"


# ══════════════════════════════════════════════════════════════════════════════
# DAMAGE TYPES
# ══════════════════════════════════════════════════════════════════════════════
enum DamageType { PHYSICAL, MAGICAL, TRUE }

static func get_damage_type_label(dt: DamageType) -> String:
	return ["Physical", "Magical", "True"][dt]

enum MoveType { MELEE, RANGED, BUFF }

# ══════════════════════════════════════════════════════════════════════════════
# MOVE TARGET MODES
# ══════════════════════════════════════════════════════════════════════════════
enum TargetMode {
	ENEMY_SINGLE_PART,
	ENEMY_WHOLE_MONSTER,
	ENEMY_ALL,
	ALLY_SINGLE_PART,
	ALLY_WHOLE_MONSTER,
	ALLY_ALL,
	SELF_MONSTER,
	ANY_SINGLE_PART,
	ANY_SINGLE_MONSTER,
}

static func get_target_label(tm: TargetMode) -> String:
	match tm:
		TargetMode.ENEMY_SINGLE_PART:   return "Single Part"
		TargetMode.ENEMY_WHOLE_MONSTER: return "Whole Monster"
		TargetMode.ENEMY_ALL:           return "All Enemy Monsters"
		TargetMode.ALLY_SINGLE_PART:    return "Ally — Single Part"
		TargetMode.ALLY_WHOLE_MONSTER:  return "Ally — Whole Monster"
		TargetMode.ALLY_ALL:            return "All Allied Monsters"
		TargetMode.SELF_MONSTER:        return "Self"
		TargetMode.ANY_SINGLE_PART:		return "Any Part"
		TargetMode.ANY_SINGLE_MONSTER:	return "Any Monster"
	return "Unknown"

static func targets_allies(tm: TargetMode) -> bool:
	return tm in [TargetMode.ALLY_SINGLE_PART, TargetMode.ALLY_WHOLE_MONSTER,
				  TargetMode.ALLY_ALL, TargetMode.SELF_MONSTER]


# ══════════════════════════════════════════════════════════════════════════════
# STATUS EFFECT IDs
# ══════════════════════════════════════════════════════════════════════════════
enum StatusID { BLEED, POISON, WEAK, STUNNED, REGENERATING, DISMEMBERED }

static func get_status_label(sid: StatusID) -> String:
	return ["Bleeding", "Poisoned", "Weakened", "Stunned", "Regenerating", "Dismembered"][sid]

static func get_status_description(sid: StatusID) -> String:
	match sid:
		StatusID.BLEED:        return "Deals damage each turn. Severity decreases over time."
		StatusID.POISON:       return "Deals damage each turn. Escalates the longer it lasts."
		StatusID.WEAK:         return "Halves damage dealt by this part's move."
		StatusID.STUNNED:      return "Part cannot act. Speed bar does not fill."
		StatusID.REGENERATING: return "Restores HP to this part each turn."
		StatusID.DISMEMBERED:  return "Missing limbs, dealing massive damage at start of turn."
	return ""

static func get_status_icon(sid: StatusID) -> String:
	return ["🩸","🟢","🔽","⚡","💚","💀"][sid]


# ══════════════════════════════════════════════════════════════════════════════
# AI PERSONALITIES
## Set directly on MonsterBody — hidden from the player, not tied to the heart.
# ══════════════════════════════════════════════════════════════════════════════
enum AIPersonality { RANDOM, HEARTBREAKER, COWARD, BERSERKER, VULTURE, BODYBREAKER, HEALER }

static func get_personality_label(p: AIPersonality) -> String:
	return ["Random", "Heartbreaker", "Coward", "Berserker", "Vulture", "Bodybreaker", "Healer"][p]

static func get_personality_description(p: AIPersonality) -> String:
	match p:
		AIPersonality.RANDOM:       return "Acts without strategy."
		AIPersonality.HEARTBREAKER: return "Obsessed with killing hearts."
		AIPersonality.COWARD:       return "Targets the weakest monster."
		AIPersonality.BERSERKER:    return "Charges the strongest foe with hardest-hitting moves."
		AIPersonality.VULTURE:      return "Hunts the most damaged part."
		AIPersonality.BODYBREAKER:  return "Strips away limbs and torso to remove moves."
		AIPersonality.HEALER:       return "Keeps allies alive above all else."
	return ""


# ══════════════════════════════════════════════════════════════════════════════
# HEART PASSIVE IDs
## Each HeartData carries one HeartPassive. These IDs label them for UI/tooltips.
## Add a new value here when creating a new HeartPassive subclass.
# ══════════════════════════════════════════════════════════════════════════════
enum HeartPassiveID {
	NONE,
	DAMAGE_REDUCTION,   ## Reduces all incoming damage by a flat amount
	THORNS,             ## Deals damage back to attacker on any hit
	VAMPIRIC,           ## Heals self for a portion of damage dealt
	ENERGISED,          ## Gains bonus energy at the start of each turn
	RESILIENT,          ## Prevents the first lethal hit once per battle
	SWIFT,              ## Bonus speed bar fill each tick
}

static func get_passive_label(pid: HeartPassiveID) -> String:
	match pid:
		HeartPassiveID.NONE:             return "None"
		HeartPassiveID.DAMAGE_REDUCTION: return "Damage Reduction"
		HeartPassiveID.THORNS:           return "Thorns"
		HeartPassiveID.VAMPIRIC:         return "Vampiric"
		HeartPassiveID.ENERGISED:        return "Energised"
		HeartPassiveID.RESILIENT:        return "Resilient"
		HeartPassiveID.SWIFT:            return "Swift"
	return "Unknown"

static func get_passive_description(pid: HeartPassiveID) -> String:
	match pid:
		HeartPassiveID.NONE:             return "This heart has no passive ability."
		HeartPassiveID.DAMAGE_REDUCTION: return "All incoming damage is reduced by a flat amount."
		HeartPassiveID.THORNS:           return "Reflects damage back to any attacker."
		HeartPassiveID.VAMPIRIC:         return "Heals the monster for a portion of all damage it deals."
		HeartPassiveID.ENERGISED:        return "Gains bonus energy at the start of each turn."
		HeartPassiveID.RESILIENT:        return "Once per battle, survives a lethal hit with 1 HP."
		HeartPassiveID.SWIFT:            return "Speed bar fills faster each tick."
	return ""


# ══════════════════════════════════════════════════════════════════════════════
# STATS
# ══════════════════════════════════════════════════════════════════════════════
enum Stat { VITALITY, SPEED, CHARISMA, LUCK, RESOURCEFULNESS, ATTACK, DEFENSE, MAGIC_ATTACK, MAGIC_DEFENSE }

static func get_stat_label(s: Stat) -> String:
	return ["Vitality", "Speed", "Charisma", "Luck", "Resourcefulness", "Attack", "Defense", "Magic Attack", "Magic Defense"][s]

static func get_stat_description(s: Stat) -> String:
	match s:
		Stat.VITALITY:
			return "Increases maximum HP."
		Stat.SPEED:
			return "Fills speed bar faster — more turns."
		Stat.CHARISMA:
			return "Increases maximum energy."
		Stat.LUCK:
			return "Raises crit chance and random effect odds."
		Stat.RESOURCEFULNESS:
			return "Energy recovered when Resting."
		Stat.ATTACK:
			return "Bonus damage added to physical attacks."
		Stat.DEFENSE:
			return "Reduces incoming physical damage."
		Stat.MAGIC_ATTACK:
			return "Bonus damage added to magic attacks."
		Stat.MAGIC_DEFENSE:
			return "Reduces incoming magical damage."
	return ""

static func all_stats() -> Array[Stat]:
	return [Stat.VITALITY, Stat.SPEED, Stat.CHARISMA,
			Stat.LUCK, Stat.RESOURCEFULNESS, Stat.ATTACK, Stat.DEFENSE, Stat.MAGIC_ATTACK, Stat.MAGIC_DEFENSE]

# ══════════════════════════════════════════════════════════════════════════════
# CONDITIONAL EFFECTS
# ══════════════════════════════════════════════════════════════════════════════
enum Conditional { TARGET_HAS_BLEED, TARGET_HP_BELOW_HALF, ACTOR_HP_BELOW_HALF }

static func get_conditional_description(cond: Conditional) -> String:
	match cond:
		Conditional.TARGET_HAS_BLEED:
			return "Target is bleeding"
		Conditional.TARGET_HP_BELOW_HALF:
			return "Target's health is at 50% or less'"
		Conditional.ACTOR_HP_BELOW_HALF:
			return "This monster's health is at 50% or less"
	return ""

# ══════════════════════════════════════════════════════════════════════════════
# TYPE SET BONUSES
## { PartType: { count_threshold: { stat_key: bonus } } }
## Edit here to tune or add new type synergies.
# ══════════════════════════════════════════════════════════════════════════════
const TYPE_SET_BONUSES: Dictionary = {
	PartType.BUG:    { 2: {Enums.Stat.DEFENSE: 10},          			4: {Enums.Stat.DEFENSE: 30} },
	PartType.SHARP:  { 2: {Enums.Stat.ATTACK: 8},             			4: {Enums.Stat.ATTACK: 20, Enums.Stat.SPEED: 5} },
	PartType.DEMON:  { 2: {Enums.Stat.ATTACK: 6, Enums.Stat.LUCK: 3},  	4: {Enums.Stat.ATTACK: 15, Enums.Stat.LUCK: 8} },
	PartType.HOLY:   { 2: {Enums.Stat.RESOURCEFULNESS: 4},    			4: {Enums.Stat.RESOURCEFULNESS: 10, Enums.Stat.CHARISMA: 5} },
	PartType.ARCANE: { 2: {Enums.Stat.CHARISMA: 5},           			4: {Enums.Stat.CHARISMA: 12, Enums.Stat.LUCK: 5} },
	PartType.FLESH:  { 2: {Enums.Stat.VITALITY: 5},           			4: {Enums.Stat.VITALITY: 15} },
}

enum RowPosition { BACK, MID, FRONT }