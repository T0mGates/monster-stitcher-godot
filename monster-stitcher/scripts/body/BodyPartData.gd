## BodyPartData.gd
class_name BodyPartData
extends Resource

var part_name			: String         	= "Unknown Part"
var parent_monster 		: MonsterBody		= null
var slot				: Enums.Slot     	= Enums.Slot.ARM
var type				: Enums.PartType 	= Enums.PartType.FLESH
var max_hp				: int 				= 20
var origin_monster_type	: PartsData.Monster

# Which Socket node this part plugs into — matches Socket.socket_id (int)
# Set to -1 for the torso (no socket needed, always at body root origin)
var socket_id			: int            	= -1

var move				: MoveData 			= null

var passive_stats		: Dictionary[Enums.Stat, int] = {
	Enums.Stat.VITALITY: 0, Enums.Stat.SPEED: 0, Enums.Stat.CHARISMA: 0, Enums.Stat.LUCK: 0,
	Enums.Stat.RESOURCEFULNESS: 0, Enums.Stat.ATTACK: 0, Enums.Stat.DEFENSE: 0, Enums.Stat.MAGIC_ATTACK: 0, Enums.Stat.MAGIC_DEFENSE: 0
}

const SPEED_BAR_MAX		: float 			= 100.0

var speed_bar			: float 			= 0.0


var statuses			: Array[StatusEffect] = []

var level				:        int      	= 1

var part_id				: int 				= -1
var socket_node			: Socket			= null

signal part_damaged(part: BodyPartData, amount: int)
signal part_destroyed(part: BodyPartData)
signal status_applied(part: BodyPartData, status: StatusEffect)
signal status_removed(part: BodyPartData, status_id: Enums.StatusID)

var current_hp: int:
	get:
		return _current_hp
	set(v):
		_current_hp = clampi(v, 0, max_hp)

var _current_hp: int = 20

static var next_part_id = 0
static func get_next_part_id():
	var to_return = next_part_id
	next_part_id += 1

	return to_return

func _init(
	name_param				: String,
	slot_param				: Enums.Slot,
	type_param				: Enums.PartType,
	origin_monster_param	: PartsData.Monster,
	move_param				: MoveData,
	max_hp_param			: int,
	stats_param				: Dictionary[Enums.Stat, int]
) -> void:

	part_name 				= name_param
	slot 					= slot_param
	type 					= type_param
	max_hp 					= max_hp_param
	origin_monster_type 	= origin_monster_param
	move 					= move_param

	for stat in Enums.Stat.values():
		passive_stats[stat] = stats_param.get(stat, 0)

	part_id 				= get_next_part_id()

func initialize(parent_param: MonsterBody) -> void:
	current_hp 		= max_hp
	speed_bar 		= 0.0
	statuses.clear()
	parent_monster  = parent_param

func force_die() -> void:
	take_damage(max_hp)

func take_damage(amount: int) -> void:
	current_hp -= amount
	emit_signal("part_damaged", self, amount)

	if current_hp <= 0:
		print("DETECTED A DESTROY FOR PART: " + part_name)
		_destroy()

func _destroy() -> void:
	socket_node.destroy_inserted_part()
	emit_signal("part_destroyed")

func heal(amount: int) -> int:
	var before = current_hp
	current_hp += amount
	return current_hp - before

func apply_status(effect: StatusEffect) -> void:
	for existing in statuses:
		if existing.get_id() == effect.get_id():
			existing.on_stack(effect)
			return

	effect.on_apply()
	statuses.append(effect)
	emit_signal("status_applied", self, effect)

func remove_status(status_id: Enums.StatusID) -> void:
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].get_id() == status_id:
			statuses[i].on_remove()
			statuses.remove_at(i)
			emit_signal("status_removed", self, status_id)
			return

func has_status(status_id: Enums.StatusID) -> bool:
	for s in statuses:
		if s.get_id() == status_id:
			return true

	return false

func tick_statuses() -> void:
	for i in range(statuses.size() - 1, -1, -1):
		var s = statuses[i]
		s.tick()

		if s.is_expired():
			s.on_remove()
			emit_signal("status_removed", self, s.get_id())
			statuses.remove_at(i)

func tick_speed(delta: float) -> bool:
	if has_status(Enums.StatusID.STUNNED):
		return false

	speed_bar += delta

	if speed_bar >= SPEED_BAR_MAX:
		speed_bar -= SPEED_BAR_MAX
		return true

	return false

func add_upgrade() -> void:
	# TODO
	#upgrade_count += 1
	level += 1
	for stat in passive_stats:
		passive_stats[stat] = int(passive_stats[stat] * 1.15)

	max_hp = int(max_hp * 1.15)
	current_hp = min(current_hp, max_hp)

func get_type_multiplier(attacker_type: Enums.PartType) -> float:
	const CHART = {
		Enums.PartType.SHARP: { Enums.PartType.BUG: 2.0,   Enums.PartType.DEMON: 0.5 },
		Enums.PartType.BUG:   { Enums.PartType.DEMON: 2.0, Enums.PartType.HOLY: 0.5  },
		Enums.PartType.DEMON: { Enums.PartType.HOLY: 2.0,  Enums.PartType.SHARP: 0.5 },
		Enums.PartType.HOLY:  { Enums.PartType.SHARP: 2.0, Enums.PartType.BUG: 0.5   },
	}

	if attacker_type in CHART and type in CHART[attacker_type]:
		return CHART[attacker_type][type]
	return 1.0

func get_stat(stat_name: Enums.Stat) -> int:
	return passive_stats.get(stat_name, 0)

func to_debug_string() -> String:
	var snames: Array[String] = []
	for s in statuses: snames.append(Enums.get_status_label(s.get_id()))
	return "[%s|%s|HP:%d/%d|%s]" % [part_name, Enums.get_type_label(type),
		current_hp, max_hp, str(snames)
	]

func set_parent_body(parent: MonsterBody):
	parent_monster = parent
