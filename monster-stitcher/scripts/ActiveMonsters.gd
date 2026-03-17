## ActiveMonsters.gd
## Autoload as "ActiveMonsters". Builds two monsters in code — no .tres files needed.
##
## Socket IDs are integers matching Socket.socket_id in a body scene.
## If you're using inspector-placed Socket nodes, the socket_id ints here
## must match what you set in the inspector on each Socket node.

extends Node

var player_monster : MonsterBody
var enemy_monster  : MonsterBody


func _ready() -> void:
	player_monster = _build_player()
	#enemy_monster  = _build_enemy()

	#player_monster = _build_enemy()
	enemy_monster = _build_player()

	player_monster.is_player_monster = true
	enemy_monster.monster_name = "Enemy Guy"


# ══════════════════════════════════════════════════════════════════════════════
# Helpers — reduce boilerplate
# ══════════════════════════════════════════════════════════════════════════════

func _build_player() -> MonsterBody:
	var heart           := HeartData.new(
		"Iron Heart",
		Enums.HeartPassiveID.DAMAGE_REDUCTION,
		{Enums.Stat.VITALITY: 2}
	)

	var slash_dmg         	:= MoveEffect.Damage.new(
		12,
		Enums.DamageType.PHYSICAL
	)

	var slash_bleed			:= MoveEffect.InflictStatus.new(
		Enums.StatusID.BLEED, 0.5, 3
	)

	var slash            	:= MoveData.new(
		"Slash",
		"Slash your foe",
		2,
		Enums.MoveType.MELEE,
		Enums.TargetMode.ENEMY_SINGLE_PART,
		[slash_dmg, slash_bleed],
		[Enums.RowPosition.FRONT, Enums.RowPosition.MID],
		[Enums.RowPosition.FRONT, Enums.RowPosition.MID],
		Enums.ClipRole.ATTACK,
		Enums.ClipRole.HIT
	)

	var mend_heal         	:= MoveEffect.HealPart.new(15)

	var mend             	:= MoveData.new(
		"Mend",
		"Mend a monster's wounds",
		3,
		Enums.MoveType.BUFF,
		Enums.TargetMode.ANY_SINGLE_PART,
		[mend_heal],
		[Enums.RowPosition.FRONT, Enums.RowPosition.MID, Enums.RowPosition.BACK],
		[Enums.RowPosition.FRONT, Enums.RowPosition.MID, Enums.RowPosition.BACK],
		Enums.ClipRole.CAST,
		Enums.ClipRole.HEAL
	)

	var pummel_damage		:= MoveEffect.Damage.new(
		6,
		Enums.DamageType.PHYSICAL
	)

	var pummel           	:= MoveData.new(
		"Pummel",
		"Pummel a foe to a pulp",
		4,
		Enums.MoveType.MELEE,
		Enums.TargetMode.ENEMY_WHOLE_MONSTER,
		[pummel_damage],
		[Enums.RowPosition.FRONT, Enums.RowPosition.MID],
		[Enums.RowPosition.FRONT, Enums.RowPosition.MID],
		Enums.ClipRole.ATTACK,
		Enums.ClipRole.HIT
	)

	var body_scene = null
	# Load your body scene — it must contain Socket nodes with matching socket_id ints
	if ResourceLoader.exists("res://scenes/bodies/Grasshopper.tscn"):
		body_scene = load("res://scenes/bodies/Grasshopper.tscn")

	var parts: Array[BodyPartData] = []
	parts.append(BodyPartData.new(
		"Grassy Head",
		Enums.Slot.HEAD,
		Enums.PartType.BUG,
		PartsData.Monster.GRASSHOPPER,
		mend,
		40,
		{Enums.Stat.VITALITY: 1, Enums.Stat.CHARISMA: 1},
		1
	))

	parts.append(BodyPartData.new(
		"Scissor Arm",
		Enums.Slot.ARM,
		Enums.PartType.BUG,
		PartsData.Monster.GRASSHOPPER,
		slash,
		20,
		{Enums.Stat.ATTACK: 1, Enums.Stat.SPEED: 1},
		2
	))

	parts.append(BodyPartData.new(
		"Scissor Arm",
		Enums.Slot.ARM,
		Enums.PartType.BUG,
		PartsData.Monster.GRASSHOPPER,
		slash,
		20,
		{Enums.Stat.ATTACK: 1, Enums.Stat.SPEED: 1},
		3
	))

	parts.append(BodyPartData.new(
		"Jumpy Leg",
		Enums.Slot.LEG,
		Enums.PartType.BUG,
		PartsData.Monster.GRASSHOPPER,
		pummel,
		15,
		{Enums.Stat.VITALITY: 1},
		4
	))

	parts.append(BodyPartData.new(
		"Jumpy Leg",
		Enums.Slot.LEG,
		Enums.PartType.BUG,
		PartsData.Monster.GRASSHOPPER,
		pummel,
		15,
		{Enums.Stat.VITALITY: 1},
		5
	))

	parts.append(BodyPartData.new(
		"Hard Shell",
		Enums.Slot.TORSO,
		Enums.PartType.BUG,
		PartsData.Monster.GRASSHOPPER,
		null,
		10,
		{Enums.Stat.DEFENSE: 5, Enums.Stat.VITALITY: 5, Enums.Stat.ATTACK: 5, Enums.Stat.SPEED: 2},
		0
	))


	# socket_id int must match a Socket node with that id in your body scene
	var m               := MonsterBody.new(
		"Grasshopper Guy",
		Enums.AIPersonality.BERSERKER,
		heart,
		parts,
		body_scene
	)

	return m


# ══════════════════════════════════════════════════════════════════════════════
# ENEMY — Six-legged demon (non-humanoid, shows off flexible socket layout)
## Body scene: res://scenes/bodies/SixLeggedGrasshopper.tscn
# ══════════════════════════════════════════════════════════════════════════════
'''
func _build_enemy() -> MonsterBody:
	var heart           := HeartData.new()
	heart.heart_name     = "Thorns Heart"
	heart.passive_id     = Enums.HeartPassiveID.THORNS
	heart.passive_stats  = _stats(0,0,0,1)

	var claw             := MoveData.new()
	claw.move_name        = "Claw"
	claw.energy_cost      = 2
	claw.target_mode      = Enums.TargetMode.ENEMY_SINGLE_PART
	var cd               := MoveEffect.Damage.new()
	cd.base_damage        = 10
	cd.damage_type        = Enums.DamageType.PHYSICAL
	var cs               := MoveEffect.InflictStatusOnCrit.new()
	cs.status_id          = Enums.StatusID.STUNNED
	cs.turns              = 1
	claw.effects          = [cd, cs]

	var venom            := MoveData.new()
	venom.move_name       = "Venom Spit"
	venom.energy_cost     = 3
	venom.target_mode     = Enums.TargetMode.ENEMY_SINGLE_PART
	var vd               := MoveEffect.Damage.new()
	vd.base_damage        = 6
	vd.damage_type        = Enums.DamageType.MAGICAL
	var vp               := MoveEffect.InflictStatus.new()
	vp.status_id          = Enums.StatusID.POISON
	vp.chance             = 0.8
	vp.turns              = 4
	venom.effects         = [vd, vp]

	var rend             := MoveData.new()
	rend.move_name        = "Rend"
	rend.energy_cost      = 5
	rend.target_mode      = Enums.TargetMode.ENEMY_SINGLE_PART
	var rd               := MoveEffect.Damage.new()
	rd.base_damage        = 20
	rd.damage_type        = Enums.DamageType.PHYSICAL
	var rb               := MoveEffect.InflictStatus.new()
	rb.status_id          = Enums.StatusID.BLEED
	rb.chance             = 1.0
	rb.turns              = 2
	rend.effects          = [rd, rb]

	var m               := MonsterBody.new()
	m.monster_name       = "Demon"
	if ResourceLoader.exists("res://scenes/bodies/SixLeggedGrasshopper.tscn"):
		m.body_scene = load("res://scenes/bodies/SixLeggedGrasshopper.tscn")
	m.ai_personality     = Enums.AIPersonality.EXECUTIONER
	m.heart              = heart
	m.parts = [
		_part(10, PartsData.Monster.GRASSHOPPER, "Head",  Enums.Slot.HEAD,  0, Enums.PartType.DEMON, 18, _stats(0,1,0,2,0,0,0,1), venom),
		_part(11, PartsData.Monster.GRASSHOPPER, "Arm",  Enums.Slot.ARM,   1, Enums.PartType.SHARP, 22, _stats(0,0,0,0,0,3), claw),
		_part(12, PartsData.Monster.GRASSHOPPER, "Arm",  Enums.Slot.ARM,   2, Enums.PartType.SHARP, 22, _stats(0,0,0,0,0,3), rend),
		_part(13, PartsData.Monster.GRASSHOPPER, "Torso", Enums.Slot.TORSO, -1,Enums.PartType.DEMON, 35, _stats(1,0,0,0,0,1)),
		_part(14, PartsData.Monster.HORSE, "HorseLeg",  Enums.Slot.LEG,   3, Enums.PartType.DEMON, 15, _stats(0,2)),
		_part(15, PartsData.Monster.HORSE, "HorseLeg",  Enums.Slot.LEG,   4, Enums.PartType.DEMON, 15, _stats(0,2)),
		_part(16, PartsData.Monster.GRASSHOPPER, "Leg",  Enums.Slot.LEG,   5, Enums.PartType.DEMON, 15, _stats(0,2)),
		_part(17, PartsData.Monster.GRASSHOPPER, "Leg",  Enums.Slot.LEG,   6, Enums.PartType.DEMON, 15, _stats(0,2)),
	]
	return m

	'''